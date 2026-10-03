/// Pure Dart VRM/VRMA parsing, validation, and renderer-neutral runtime APIs.
library;

export 'src/diagnostics.dart'
    show
        VrmDiagnostic,
        VrmDiagnosticSeverity,
        VrmError,
        VrmInfo,
        VrmInvalidAssetException,
        VrmParseResult,
        VrmValidationMode,
        VrmValidationResult,
        VrmWarning;
export 'src/gltf/gltf_animation_types.dart'
    show
        GltfAnimation,
        GltfAnimationChannel,
        GltfAnimationEvaluator,
        GltfAnimationFrame,
        GltfAnimationSampler,
        GltfNodePose,
        VrmProceduralMotion,
        VrmProgrammaticPose;
export 'src/gltf/gltf_camera_types.dart'
    show
        GltfCamera,
        GltfCameraOrthographic,
        GltfCameraPerspective,
        GltfCameraType;
export 'src/gltf/gltf_material_types.dart'
    show
        GltfAlphaMode,
        GltfMaterial,
        GltfMaterialRenderMode,
        GltfTextureTransform,
        VrmMToonMaterial,
        VrmMToonOutlineWidthMode,
        VrmTextureInfo;
export 'src/gltf/gltf_mesh_types.dart' show GltfMesh, GltfMeshPrimitive;
export 'src/gltf/gltf_node_constraint_types.dart'
    show
        VrmNodeConstraint,
        VrmNodeConstraintAimAxis,
        VrmNodeConstraintKind,
        VrmNodeConstraintRollAxis;
export 'src/gltf/gltf_resource_types.dart'
    show
        GltfAccessor,
        GltfAccessorSparse,
        GltfBuffer,
        GltfBufferView,
        GltfImage,
        GltfSampler,
        GltfSkin,
        GltfTexture;
export 'src/gltf/gltf_scene_types.dart' show GltfNode, GltfScene;
export 'src/gltf/gltf_types.dart' show GltfAsset, GltfUriResolver;
export 'src/math_types.dart'
    show VrmMatrix4, VrmVector2, VrmVector3, VrmVector4;
export 'src/runtime/expression_controller.dart' show VrmExpressionController;
export 'src/runtime/look_at_controller.dart' show VrmLookAtController;
export 'src/runtime/motion_controller.dart'
    show
        VrmAdditiveMotionLayers,
        VrmHumanoidSample,
        VrmMotionController,
        VrmSampledHumanoidMotion,
        VrmSampledHumanoidPlayback;
export 'src/runtime/motion_retargeter.dart'
    show VrmFkHumanoidRetargeter, VrmHumanoidRetargeter, VrmRetargetedBonePose;
export 'src/runtime/node_constraint_controller.dart'
    show VrmNodeConstraintController;
export 'src/runtime/runtime.dart'
    show
        VrmBlinkController,
        VrmEmotionController,
        VrmFirstPersonController,
        VrmLipSyncController,
        VrmRuntime;
export 'src/runtime/scene_binding.dart'
    show
        VrmMaterialBinding,
        VrmMaterialTextureSlot,
        VrmMeshBinding,
        VrmModelRootBinding,
        VrmModelWorldBinding,
        VrmNodeBinding,
        VrmPerTextureMaterialBinding,
        VrmSceneBinding;
export 'src/runtime/spring_bone_controller.dart' show VrmSpringBoneController;
export 'src/vrm/spring_bone_types.dart'
    show
        VrmSpringBone,
        VrmSpringBoneCollider,
        VrmSpringBoneColliderGroup,
        VrmSpringBoneColliderShape,
        VrmSpringBoneColliderShapeType,
        VrmSpringBoneJoint,
        VrmSpringBoneSpring;
export 'src/vrm/vrm_assets.dart'
    show VrmAnimationAsset, VrmAnimationExtension, VrmModel;
export 'src/vrm/vrm_enums.dart'
    show
        VrmEmotion,
        VrmExpressionOverrideMode,
        VrmExpressionPreset,
        VrmFirstPersonMeshAnnotationType,
        VrmFirstPersonView,
        VrmHumanoidBone,
        VrmLipSyncPreset,
        VrmMetaAvatarPermission,
        VrmMetaCommercialUsage,
        VrmMetaCreditNotation,
        VrmMetaModification,
        VrmSourceVersion,
        VrmViseme;
export 'src/vrm/vrm_types.dart'
    show
        VrmExpression,
        VrmExpressions,
        VrmExtension,
        VrmFirstPerson,
        VrmFirstPersonMeshAnnotation,
        VrmHumanBone,
        VrmHumanoid,
        VrmLookAt,
        VrmLookAtRangeMap,
        VrmLookAtType,
        VrmMaterialColorBind,
        VrmMeta,
        VrmMorphTargetBind,
        VrmTextureTransformBind;
export 'src/vrm0/vrm0_types.dart'
    show
        Vrm0BlendShapeBind,
        Vrm0BlendShapeGroup,
        Vrm0BlendShapeMaster,
        Vrm0Collider,
        Vrm0ColliderGroup,
        Vrm0DegreeMap,
        Vrm0Extension,
        Vrm0FirstPerson,
        Vrm0HumanBone,
        Vrm0Humanoid,
        Vrm0MaterialProperty,
        Vrm0MaterialValueBind,
        Vrm0MeshAnnotation,
        Vrm0Meta,
        Vrm0SecondaryAnimation,
        Vrm0SpringBoneGroup;
