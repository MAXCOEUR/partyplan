//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'mfa_verify_request.g.dart';

/// MfaVerifyRequest
///
/// Properties:
/// * [challengeToken] 
/// * [code] 
@BuiltValue()
abstract class MfaVerifyRequest implements Built<MfaVerifyRequest, MfaVerifyRequestBuilder> {
  @BuiltValueField(wireName: r'challengeToken')
  String get challengeToken;

  @BuiltValueField(wireName: r'code')
  String get code;

  MfaVerifyRequest._();

  factory MfaVerifyRequest([void updates(MfaVerifyRequestBuilder b)]) = _$MfaVerifyRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(MfaVerifyRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<MfaVerifyRequest> get serializer => _$MfaVerifyRequestSerializer();
}

class _$MfaVerifyRequestSerializer implements PrimitiveSerializer<MfaVerifyRequest> {
  @override
  final Iterable<Type> types = const [MfaVerifyRequest, _$MfaVerifyRequest];

  @override
  final String wireName = r'MfaVerifyRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    MfaVerifyRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'challengeToken';
    yield serializers.serialize(
      object.challengeToken,
      specifiedType: const FullType(String),
    );
    yield r'code';
    yield serializers.serialize(
      object.code,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    MfaVerifyRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required MfaVerifyRequestBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'challengeToken':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.challengeToken = valueDes;
          break;
        case r'code':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.code = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  MfaVerifyRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = MfaVerifyRequestBuilder();
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


