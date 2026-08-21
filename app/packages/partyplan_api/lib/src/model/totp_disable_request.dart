//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'totp_disable_request.g.dart';

/// TotpDisableRequest
///
/// Properties:
/// * [password] 
@BuiltValue()
abstract class TotpDisableRequest implements Built<TotpDisableRequest, TotpDisableRequestBuilder> {
  @BuiltValueField(wireName: r'password')
  String get password;

  TotpDisableRequest._();

  factory TotpDisableRequest([void updates(TotpDisableRequestBuilder b)]) = _$TotpDisableRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(TotpDisableRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<TotpDisableRequest> get serializer => _$TotpDisableRequestSerializer();
}

class _$TotpDisableRequestSerializer implements PrimitiveSerializer<TotpDisableRequest> {
  @override
  final Iterable<Type> types = const [TotpDisableRequest, _$TotpDisableRequest];

  @override
  final String wireName = r'TotpDisableRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    TotpDisableRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'password';
    yield serializers.serialize(
      object.password,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    TotpDisableRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required TotpDisableRequestBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'password':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.password = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  TotpDisableRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = TotpDisableRequestBuilder();
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


