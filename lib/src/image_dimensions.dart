part of '../flvtterm.dart';

({int width, int height})? _imageDimensions(Uint8List bytes) {
  if (_hasPngSignature(bytes)) return _pngDimensions(bytes);
  if (_hasJpegSignature(bytes)) return _jpegDimensions(bytes);
  return null;
}

({int width, int height})? _pngDimensions(Uint8List bytes) {
  if (bytes.length < 24 ||
      bytes[12] != 0x49 ||
      bytes[13] != 0x48 ||
      bytes[14] != 0x44 ||
      bytes[15] != 0x52) {
    return null;
  }
  final width = _readUint32BigEndian(bytes, 16);
  final height = _readUint32BigEndian(bytes, 20);
  return width > 0 && height > 0 ? (width: width, height: height) : null;
}

({int width, int height})? _jpegDimensions(Uint8List bytes) {
  var offset = 2;
  while (offset < bytes.length) {
    while (offset < bytes.length && bytes[offset] != 0xff) {
      offset++;
    }
    while (offset < bytes.length && bytes[offset] == 0xff) {
      offset++;
    }
    if (offset >= bytes.length) return null;

    final marker = bytes[offset++];
    if (marker == 0x00) continue;
    if (marker == 0xd9 || marker == 0xda) return null;
    if (marker == 0x01 ||
        marker == 0xd8 ||
        (marker >= 0xd0 && marker <= 0xd7)) {
      continue;
    }
    if (offset + 1 >= bytes.length) return null;

    final segmentLength = (bytes[offset] << 8) | bytes[offset + 1];
    if (segmentLength < 2 || offset + segmentLength > bytes.length) return null;
    if (_isJpegStartOfFrame(marker)) {
      if (segmentLength < 7) return null;
      final height = (bytes[offset + 3] << 8) | bytes[offset + 4];
      final width = (bytes[offset + 5] << 8) | bytes[offset + 6];
      return width > 0 && height > 0 ? (width: width, height: height) : null;
    }
    offset += segmentLength;
  }
  return null;
}

bool _isJpegStartOfFrame(int marker) =>
    marker >= 0xc0 &&
    marker <= 0xcf &&
    marker != 0xc4 &&
    marker != 0xc8 &&
    marker != 0xcc;

int _readUint32BigEndian(Uint8List bytes, int offset) =>
    (bytes[offset] << 24) |
    (bytes[offset + 1] << 16) |
    (bytes[offset + 2] << 8) |
    bytes[offset + 3];
