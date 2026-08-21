//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'external_sign_in_request.g.dart';

/// Jeton d'identité obtenu auprès du fournisseur par le client.
///
/// Properties:
/// * [idToken] 
@BuiltValue()
abstract class ExternalSignInRequest implements Built<ExternalSignInRequest, ExternalSignInRequestBuilder> {
  @BuiltValueField(wireName: r'idToken')
  String get idToken;

  ExternalSignInRequest._();

  factory ExternalSignInRequest([void updates(ExternalSignInRequestBuilder b)]) = _$ExternalSignInRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ExternalSignInRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ExternalSignInRequest> get serializer => _$ExternalSignInRequestSerializer();
}

class _$ExternalSignInRequestSerializer implements PrimitiveSerializer<ExternalSignInRequest> {
  @override
  final Iterable<Type> types = const [ExternalSignInRequest, _$ExternalSignInRequest];

  @override
  final String wireName = r'ExternalSignInRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ExternalSignInRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'idToken';
    yield serializers.serialize(
      object.idToken,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ExternalSignInRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ExternalSignInRequestBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'idToken':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.idToken = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ExternalSignInRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ExternalSignInRequestBuilder();
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


