// Flutter Scene 0.23.0 keeps the render-pass and texture-allocation types used
// by imported materials internal. This adapter is exact-version pinned while
// that compatibility seam exists.
// ignore_for_file: implementation_imports, invalid_use_of_internal_member, public_member_api_docs

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_scene/scene.dart' as scene;
import 'package:flutter_scene/src/gpu/gpu.dart' as gpu;
import 'package:flvtterm/flvtterm.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'flutter_scene_gltf_mapping.dart';

const _shaderBundleAsset =
    'packages/flvtterm_flutter_scene/build/shaderbundles/vrm_materials.shaderbundle';

/// Package-internal seam used by the renderer binding to update expression-
/// driven texture transforms without knowing the concrete scene material.
abstract interface class FlutterScenePerTextureMaterial {
  Set<VrmMaterialTextureSlot> get textureTransformSlots;

  void setTextureTransformForTexture(
    VrmMaterialTextureSlot slot, {
    required VrmVector2 scale,
    required VrmVector2 offset,
  });
}

final class FlutterSceneMaterialCorrectionResult {
  FlutterSceneMaterialCorrectionResult({
    required Set<int> alphaCorrectedMaterialIndices,
    required Set<int> straightAlphaTextureIndices,
  }) : alphaCorrectedMaterialIndices = Set.unmodifiable(
         alphaCorrectedMaterialIndices,
       ),
       straightAlphaTextureIndices = Set.unmodifiable(
         straightAlphaTextureIndices,
       );

  final Set<int> alphaCorrectedMaterialIndices;
  final Set<int> straightAlphaTextureIndices;
}

Future<FlutterSceneMaterialCorrectionResult> correctFlutterSceneMaterials(
  scene.Node root,
  VrmModel model,
) async {
  final slots = _importedMaterialSlots(root, model).toList(growable: false);
  if (slots.isEmpty) {
    return FlutterSceneMaterialCorrectionResult(
      alphaCorrectedMaterialIndices: const {},
      straightAlphaTextureIndices: const {},
    );
  }

  final shaderLibrary = await gpu.loadShaderLibraryAsync(_shaderBundleAsset);
  final unlitShader = shaderLibrary?['VrmUnlitFragment'];
  if (unlitShader == null) {
    throw StateError(
      'Could not load the flvtterm Flutter Scene material shader bundle.',
    );
  }

  final textures = _StraightTextureCache(model.gltf);
  final correctedMaterials = <int>{};
  for (final slot in slots) {
    final gltfMaterial = slot.material;
    final imported = slot.primitive.material;
    final preferredMode = model.preferredRenderModeForMaterial(
      gltfMaterial.index,
      supportsMToon: false,
    );
    if (preferredMode == GltfMaterialRenderMode.unlit &&
        (imported is scene.UnlitMaterial ||
            imported is scene.PhysicallyBasedMaterial)) {
      final sourceTexture = switch (imported) {
        scene.UnlitMaterial material => material.baseColorTexture,
        scene.PhysicallyBasedMaterial material => material.baseColorTexture,
        _ => throw StateError('Unreachable Flutter Scene material type.'),
      };
      final sourceFactor = switch (imported) {
        scene.UnlitMaterial material => material.baseColorFactor,
        scene.PhysicallyBasedMaterial material => material.baseColorFactor,
        _ => throw StateError('Unreachable Flutter Scene material type.'),
      };
      final vertexColorWeight = switch (imported) {
        scene.UnlitMaterial material => material.vertexColorWeight,
        scene.PhysicallyBasedMaterial material => material.vertexColorWeight,
        _ => throw StateError('Unreachable Flutter Scene material type.'),
      };
      final baseTexture = await textures.resolve(
        gltfMaterial.baseColorTexture?.index,
        sourceTexture,
      );
      final baseColorSampler = _samplerForTexture(
        model.gltf,
        gltfMaterial.baseColorTexture?.index,
      );
      slot.primitive.material = _CorrectedUnlitMaterial(
        sourceBaseColorFactor: sourceFactor,
        vertexColorWeight: vertexColorWeight,
        material: gltfMaterial,
        fragmentShader: unlitShader,
        baseColorTexture:
            baseTexture ??
            scene.GpuTextureSource(
              scene.Material.getWhitePlaceholderTexture(),
              sampler: baseColorSampler,
            ),
        baseColorSampler: baseColorSampler,
      );
      correctedMaterials.add(gltfMaterial.index);
      continue;
    }
    if (imported is scene.PhysicallyBasedMaterial) {
      imported.baseColorTexture = await textures.resolve(
        gltfMaterial.baseColorTexture?.index,
        imported.baseColorTexture,
      );
      imported.metallicRoughnessTexture = await textures.resolve(
        gltfMaterial.metallicRoughnessTexture?.index,
        imported.metallicRoughnessTexture,
      );
      imported.normalTexture = await textures.resolve(
        gltfMaterial.normalTexture?.index,
        imported.normalTexture,
      );
      imported.occlusionTexture = await textures.resolve(
        gltfMaterial.occlusionTexture?.index,
        imported.occlusionTexture,
      );
      imported.emissiveTexture = await textures.resolve(
        gltfMaterial.emissiveTexture?.index,
        imported.emissiveTexture,
      );
      slot.primitive.material = _CorrectedPbrMaterial(
        source: imported,
        material: gltfMaterial,
      );
      correctedMaterials.add(gltfMaterial.index);
    }
  }

  return FlutterSceneMaterialCorrectionResult(
    alphaCorrectedMaterialIndices: correctedMaterials,
    straightAlphaTextureIndices: textures.correctedTextureIndices,
  );
}

final class _StraightTextureCache {
  _StraightTextureCache(this.gltf);

  final GltfAsset gltf;
  final Map<int, scene.TextureSource> _textures = {};
  final Set<int> correctedTextureIndices = {};

  Future<scene.TextureSource?> resolve(
    int? textureIndex,
    scene.TextureSource? imported,
  ) async {
    if (textureIndex == null) return imported;
    final cached = _textures[textureIndex];
    if (cached != null) return cached;
    if (textureIndex < 0 || textureIndex >= gltf.textures.length) {
      return imported;
    }
    final imageIndex = gltf.textures[textureIndex].source;
    if (imageIndex == null ||
        imageIndex < 0 ||
        imageIndex >= gltf.images.length) {
      return imported;
    }
    final encoded = gltf.images[imageIndex].data;
    if (encoded == null) return imported;
    final decoded = await _decodeStraightRgba(encoded);
    final texture = scene.Texture2D.fromPixels(
      decoded.rgba.buffer.asUint8List(
        decoded.rgba.offsetInBytes,
        decoded.rgba.lengthInBytes,
      ),
      decoded.width,
      decoded.height,
    );
    final sampled = scene.GpuTextureSource(
      texture.sampledTexture!,
      sampler: _samplerForTexture(gltf, textureIndex),
    );
    _textures[textureIndex] = sampled;
    correctedTextureIndices.add(textureIndex);
    return sampled;
  }
}

Future<_DecodedImage> _decodeStraightRgba(Uint8List encoded) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(encoded);
  // instantiateImageCodecFromBuffer takes ownership and disposes [buffer].
  final codec = await ui.instantiateImageCodecFromBuffer(buffer);
  try {
    final frame = await codec.getNextFrame();
    final image = frame.image;
    try {
      final rgba = await image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      if (rgba == null) {
        throw StateError('Flutter could not decode a glTF image as RGBA.');
      }
      return _DecodedImage(image.width, image.height, rgba);
    } finally {
      image.dispose();
    }
  } finally {
    codec.dispose();
  }
}

final class _DecodedImage {
  const _DecodedImage(this.width, this.height, this.rgba);

  final int width;
  final int height;
  final ByteData rgba;
}

final class _CorrectedUnlitMaterial extends scene.ShaderMaterial
    implements FlutterScenePerTextureMaterial {
  _CorrectedUnlitMaterial({
    required vm.Vector4 sourceBaseColorFactor,
    required this.vertexColorWeight,
    required GltfMaterial material,
    required gpu.Shader fragmentShader,
    required scene.TextureSource baseColorTexture,
    required gpu.SamplerOptions baseColorSampler,
  }) : _alphaMode = material.alphaMode,
       _alphaCutoff = material.alphaCutoff,
       _baseColorTexture = baseColorTexture,
       _baseColorSampler = baseColorSampler,
       _textureTransform = _TextureTransform.from(
         material.baseColorTexture?.textureTransform,
       ),
       baseColorFactor = sourceBaseColorFactor.clone(),
       super(
         fragmentShader: fragmentShader,
         isOpaqueOverride: material.alphaMode != GltfAlphaMode.blend,
         cullingMode: material.doubleSided
             ? gpu.CullMode.none
             : gpu.CullMode.backFace,
       ) {
    doubleSided = material.doubleSided;
    _baseColorTexCoord =
        material.baseColorTexture?.textureTransform?.texCoord ??
        material.baseColorTexture?.texCoord ??
        0;
  }

  late final int _baseColorTexCoord;
  final GltfAlphaMode _alphaMode;
  final double _alphaCutoff;
  final scene.TextureSource _baseColorTexture;
  final gpu.SamplerOptions _baseColorSampler;
  _TextureTransform _textureTransform;
  vm.Vector4 baseColorFactor;
  double vertexColorWeight;

  @override
  Set<VrmMaterialTextureSlot> get textureTransformSlots => const {
    VrmMaterialTextureSlot.baseColor,
  };

  @override
  void setTextureTransformForTexture(
    VrmMaterialTextureSlot slot, {
    required VrmVector2 scale,
    required VrmVector2 offset,
  }) {
    if (slot != VrmMaterialTextureSlot.baseColor) return;
    _textureTransform = _TextureTransform(
      scaleX: scale.x,
      scaleY: scale.y,
      offsetX: offset.x,
      offsetY: offset.y,
      rotation: _textureTransform.rotation,
    );
  }

  @override
  void bind(
    gpu.RenderPass pass,
    scene.TransientWriter transientsBuffer,
    scene.Lighting lighting,
  ) {
    isOpaqueOverride = _alphaMode != GltfAlphaMode.blend;
    cullingMode = doubleSided ? gpu.CullMode.none : gpu.CullMode.backFace;
    setUniformBlock(
      'MaterialInfo',
      ByteData.sublistView(
        Float32List.fromList([
          baseColorFactor.r,
          baseColorFactor.g,
          baseColorFactor.b,
          baseColorFactor.a,
          vertexColorWeight,
          _alphaMode.index.toDouble(),
          _alphaCutoff,
          lodFade,
          _baseColorTexCoord.toDouble(),
        ]),
      ),
    );
    setUniformBlock('TextureInfo', _textureTransform.uniformBytes);
    setTexture(
      'base_color_texture',
      _baseColorTexture,
      sampler: _baseColorSampler,
    );
    super.bind(pass, transientsBuffer, lighting);
  }
}

final class _CorrectedPbrMaterial extends scene.PhysicallyBasedMaterial
    implements FlutterScenePerTextureMaterial {
  _CorrectedPbrMaterial({
    required scene.PhysicallyBasedMaterial source,
    required GltfMaterial material,
  }) : _gltfAlphaMode = material.alphaMode,
       _textureTransforms = _pbrTextureTransforms(material),
       super(
         baseColorTexture: source.baseColorTexture,
         metallicRoughnessTexture: source.metallicRoughnessTexture,
         normalTexture: source.normalTexture,
         emissiveTexture: source.emissiveTexture,
         occlusionTexture: source.occlusionTexture,
         environment: source.environment,
       ) {
    baseColorFactor = source.baseColorFactor.clone();
    vertexColorWeight = source.vertexColorWeight;
    metallicFactor = source.metallicFactor;
    roughnessFactor = source.roughnessFactor;
    normalScale = source.normalScale;
    emissiveFactor = source.emissiveFactor.clone();
    occlusionStrength = source.occlusionStrength;
    baseColorTextureTexCoord = source.baseColorTextureTexCoord;
    metallicRoughnessTextureTexCoord = source.metallicRoughnessTextureTexCoord;
    normalTextureTexCoord = source.normalTextureTexCoord;
    occlusionTextureTexCoord = source.occlusionTextureTexCoord;
    emissiveTextureTexCoord = source.emissiveTextureTexCoord;
    alphaMode = _sceneAlphaMode(material.alphaMode);
    alphaCutoff = material.alphaCutoff;
    doubleSided = material.doubleSided;
    _applyTextureTransforms();
  }

  final GltfAlphaMode _gltfAlphaMode;
  final Map<VrmMaterialTextureSlot, _TextureTransform> _textureTransforms;

  @override
  bool isOpaque() => _gltfAlphaMode != GltfAlphaMode.blend;

  @override
  Set<VrmMaterialTextureSlot> get textureTransformSlots =>
      Set.unmodifiable(_textureTransforms.keys);

  @override
  void setTextureTransformForTexture(
    VrmMaterialTextureSlot slot, {
    required VrmVector2 scale,
    required VrmVector2 offset,
  }) {
    final current = _textureTransforms[slot];
    if (current == null) return;
    _textureTransforms[slot] = _TextureTransform(
      scaleX: scale.x,
      scaleY: scale.y,
      offsetX: offset.x,
      offsetY: offset.y,
      rotation: current.rotation,
    );
    _applyTextureTransforms();
  }

  void _applyTextureTransforms() {
    scene.TextureTransform transform(VrmMaterialTextureSlot slot) {
      final value = _textureTransforms[slot]!;
      return scene.TextureTransform(
        scale: vm.Vector2(value.scaleX, value.scaleY),
        offset: vm.Vector2(value.offsetX, value.offsetY),
        rotation: value.rotation,
      );
    }

    baseColorTextureTransform = transform(VrmMaterialTextureSlot.baseColor);
    metallicRoughnessTextureTransform = transform(
      VrmMaterialTextureSlot.metallicRoughness,
    );
    normalTextureTransform = transform(VrmMaterialTextureSlot.normal);
    occlusionTextureTransform = transform(VrmMaterialTextureSlot.occlusion);
    emissiveTextureTransform = transform(VrmMaterialTextureSlot.emissive);
  }

  @override
  void bind(
    gpu.RenderPass pass,
    scene.TransientWriter transientsBuffer,
    scene.Lighting lighting,
  ) {
    final originalAlpha = baseColorFactor.a;
    final originalMode = alphaMode;
    final originalCutoff = alphaCutoff;
    if (_gltfAlphaMode == GltfAlphaMode.opaque) {
      // Keep glTF OPAQUE independent from source alpha. The upstream MASK
      // path forces surviving fragments opaque; zero accepts every fragment.
      baseColorFactor.a = 1;
      alphaMode = scene.AlphaMode.mask;
      alphaCutoff = 0;
    }
    try {
      super.bind(pass, transientsBuffer, lighting);
    } finally {
      baseColorFactor.a = originalAlpha;
      alphaMode = originalMode;
      alphaCutoff = originalCutoff;
    }
  }
}

scene.AlphaMode _sceneAlphaMode(GltfAlphaMode mode) => switch (mode) {
  GltfAlphaMode.opaque => scene.AlphaMode.opaque,
  GltfAlphaMode.mask => scene.AlphaMode.mask,
  GltfAlphaMode.blend => scene.AlphaMode.blend,
};

final class _TextureTransform {
  const _TextureTransform({
    required this.scaleX,
    required this.scaleY,
    required this.offsetX,
    required this.offsetY,
    required this.rotation,
  });

  factory _TextureTransform.from(GltfTextureTransform? transform) =>
      _TextureTransform(
        scaleX: transform?.scale.x ?? 1,
        scaleY: transform?.scale.y ?? 1,
        offsetX: transform?.offset.x ?? 0,
        offsetY: transform?.offset.y ?? 0,
        rotation: transform?.rotation ?? 0,
      );

  final double scaleX;
  final double scaleY;
  final double offsetX;
  final double offsetY;
  final double rotation;

  ByteData get uniformBytes => ByteData.sublistView(
    Float32List.fromList([
      scaleX,
      scaleY,
      offsetX,
      offsetY,
      math.cos(rotation),
      math.sin(rotation),
      0,
      0,
    ]),
  );
}

Map<VrmMaterialTextureSlot, _TextureTransform> _pbrTextureTransforms(
  GltfMaterial material,
) => {
  VrmMaterialTextureSlot.baseColor: _TextureTransform.from(
    material.baseColorTexture?.textureTransform,
  ),
  VrmMaterialTextureSlot.metallicRoughness: _TextureTransform.from(
    material.metallicRoughnessTexture?.textureTransform,
  ),
  VrmMaterialTextureSlot.normal: _TextureTransform.from(
    material.normalTexture?.textureTransform,
  ),
  VrmMaterialTextureSlot.occlusion: _TextureTransform.from(
    material.occlusionTexture?.textureTransform,
  ),
  VrmMaterialTextureSlot.emissive: _TextureTransform.from(
    material.emissiveTexture?.textureTransform,
  ),
};

gpu.SamplerOptions _samplerForTexture(GltfAsset gltf, int? textureIndex) {
  GltfSampler? sampler;
  if (textureIndex != null &&
      textureIndex >= 0 &&
      textureIndex < gltf.textures.length) {
    final samplerIndex = gltf.textures[textureIndex].sampler;
    if (samplerIndex != null &&
        samplerIndex >= 0 &&
        samplerIndex < gltf.samplers.length) {
      sampler = gltf.samplers[samplerIndex];
    }
  }
  return gpu.SamplerOptions(
    minFilter: switch (sampler?.minFilter) {
      null || 9729 || 9985 || 9987 => gpu.MinMagFilter.linear,
      _ => gpu.MinMagFilter.nearest,
    },
    magFilter: switch (sampler?.magFilter) {
      null || 9729 => gpu.MinMagFilter.linear,
      _ => gpu.MinMagFilter.nearest,
    },
    // Texture2D builds the mip chain; preserve the authored nearest/linear
    // choice between adjacent levels.
    mipFilter: switch (sampler?.minFilter) {
      9986 || 9987 => gpu.MipFilter.linear,
      _ => gpu.MipFilter.nearest,
    },
    widthAddressMode: _addressMode(sampler?.wrapS),
    heightAddressMode: _addressMode(sampler?.wrapT),
  );
}

gpu.SamplerAddressMode _addressMode(int? value) => switch (value) {
  33071 => gpu.SamplerAddressMode.clampToEdge,
  33648 => gpu.SamplerAddressMode.mirror,
  _ => gpu.SamplerAddressMode.repeat,
};

Iterable<({GltfMaterial material, scene.MeshPrimitive primitive})>
_importedMaterialSlots(scene.Node root, VrmModel model) sync* {
  final nodes = mapFlutterSceneNodesByGltfHierarchy(root, model.gltf);
  for (final entry in nodes.entries) {
    final gltfNode = model.gltf.nodes[entry.key];
    final meshIndex = gltfNode.mesh;
    if (meshIndex == null || meshIndex >= model.gltf.meshes.length) continue;
    final scenePrimitives = entry.value.mesh?.primitives;
    if (scenePrimitives == null) continue;
    final gltfPrimitives = materialAlignedFlutterScenePrimitives(
      model.gltf.meshes[meshIndex].primitives,
      scenePrimitives.length,
    );
    final count = math.min(gltfPrimitives.length, scenePrimitives.length);
    for (var index = 0; index < count; index++) {
      final materialIndex = gltfPrimitives[index].material;
      if (materialIndex == null ||
          materialIndex < 0 ||
          materialIndex >= model.gltf.materials.length) {
        continue;
      }
      yield (
        material: model.gltf.materials[materialIndex],
        primitive: scenePrimitives[index],
      );
    }
  }
}
