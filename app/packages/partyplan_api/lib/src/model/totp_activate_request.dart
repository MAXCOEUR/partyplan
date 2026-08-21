//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'totp_activate_request.g.dart';

/// TotpActivateRequest
///
/// Properties:
/// * [code] 
@BuiltValue()
abstract class TotpActivateRequest implements Built<TotpActivateRequest, TotpActivateRequestBuilder> {
  @BuiltValueField(wireName: r'code')
  String get code;

  TotpActivateRequest._();

  factory TotpActivateRequest([void updates(TotpActivateRequestBuilder b)]) = _$TotpActivateRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(TotpActivateRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<TotpActivateRequest> get serializer => _$TotpActivateRequestSerializer();
}

class _$TotpActivateRequestSerializer implements PrimitiveSerializer<TotpActivateRequest> {
  @override
  final Iterable<Type> types = const [TotpActivateRequest, _$TotpActivateRequest];

  @override
  final String wireName = r'TotpActivateRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    TotpActivateRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'code';
    yield serializers.serialize(
      object.code,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    TotpActivateRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required TotpActivateRequestBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
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
  TotpActivateRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = TotpActivateRequestBuilder();
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


