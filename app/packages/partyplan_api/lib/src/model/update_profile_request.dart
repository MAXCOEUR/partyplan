//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'update_profile_request.g.dart';

/// UpdateProfileRequest
///
/// Properties:
/// * [displayName] 
/// * [locale] 
/// * [timezone] 
@BuiltValue()
abstract class UpdateProfileRequest implements Built<UpdateProfileRequest, UpdateProfileRequestBuilder> {
  @BuiltValueField(wireName: r'displayName')
  String? get displayName;

  @BuiltValueField(wireName: r'locale')
  String? get locale;

  @BuiltValueField(wireName: r'timezone')
  String? get timezone;

  UpdateProfileRequest._();

  factory UpdateProfileRequest([void updates(UpdateProfileRequestBuilder b)]) = _$UpdateProfileRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(UpdateProfileRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<UpdateProfileRequest> get serializer => _$UpdateProfileRequestSerializer();
}

class _$UpdateProfileRequestSerializer implements PrimitiveSerializer<UpdateProfileRequest> {
  @override
  final Iterable<Type> types = const [UpdateProfileRequest, _$UpdateProfileRequest];

  @override
  final String wireName = r'UpdateProfileRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    UpdateProfileRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'displayName';
    yield object.displayName == null ? null : serializers.serialize(
      object.displayName,
      specifiedType: const FullType.nullable(String),
    );
    yield r'locale';
    yield object.locale == null ? null : serializers.serialize(
      object.locale,
      specifiedType: const FullType.nullable(String),
    );
    yield r'timezone';
    yield object.timezone == null ? null : serializers.serialize(
      object.timezone,
      specifiedType: const FullType.nullable(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    UpdateProfileRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required UpdateProfileRequestBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'displayName':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.displayName = valueDes;
          break;
        case r'locale':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.locale = valueDes;
          break;
        case r'timezone':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.timezone = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  UpdateProfileRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = UpdateProfileRequestBuilder();
    final serializedList = (serialized as Iterable<Object?>).toList();
    final unhandled = <Object?>[];
    _deserializeProperties(
      serializers,
      serialized,
      specifiedType: specifiedType,
      serializedList: serializedList,
      unhandled: unhandled,
      result: result,
    );
    return result.build();
  }
}


