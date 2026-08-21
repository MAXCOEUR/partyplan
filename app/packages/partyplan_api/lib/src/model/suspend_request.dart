//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'suspend_request.g.dart';

/// SuspendRequest
///
/// Properties:
/// * [reason] 
@BuiltValue()
abstract class SuspendRequest implements Built<SuspendRequest, SuspendRequestBuilder> {
  @BuiltValueField(wireName: r'reason')
  String get reason;

  SuspendRequest._();

  factory SuspendRequest([void updates(SuspendRequestBuilder b)]) = _$SuspendRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(SuspendRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<SuspendRequest> get serializer => _$SuspendRequestSerializer();
}

class _$SuspendRequestSerializer implements PrimitiveSerializer<SuspendRequest> {
  @override
  final Iterable<Type> types = const [SuspendRequest, _$SuspendRequest];

  @override
  final String wireName = r'SuspendRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    SuspendRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'reason';
    yield serializers.serialize(
      object.reason,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    SuspendRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required SuspendRequestBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'reason':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.reason = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  SuspendRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SuspendRequestBuilder();
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


