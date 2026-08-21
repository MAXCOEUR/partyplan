//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'join_body.g.dart';

/// JoinBody
///
/// Properties:
/// * [displayName] 
/// * [status] 
/// * [arrivalTime] 
@BuiltValue()
abstract class JoinBody implements Built<JoinBody, JoinBodyBuilder> {
  @BuiltValueField(wireName: r'displayName')
  String get displayName;

  @BuiltValueField(wireName: r'status')
  String get status;

  @BuiltValueField(wireName: r'arrivalTime')
  String? get arrivalTime;

  JoinBody._();

  factory JoinBody([void updates(JoinBodyBuilder b)]) = _$JoinBody;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(JoinBodyBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<JoinBody> get serializer => _$JoinBodySerializer();
}

class _$JoinBodySerializer implements PrimitiveSerializer<JoinBody> {
  @override
  final Iterable<Type> types = const [JoinBody, _$JoinBody];

  @override
  final String wireName = r'JoinBody';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    JoinBody object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'displayName';
    yield serializers.serialize(
      object.displayName,
      specifiedType: const FullType(String),
    );
    yield r'status';
    yield serializers.serialize(
      object.status,
      specifiedType: const FullType(String),
    );
    yield r'arrivalTime';
    yield object.arrivalTime == null ? null : serializers.serialize(
      object.arrivalTime,
      specifiedType: const FullType.nullable(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    JoinBody object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required JoinBodyBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'displayName':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.displayName = valueDes;
          break;
        case r'status':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.status = valueDes;
          break;
        case r'arrivalTime':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.arrivalTime = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  JoinBody deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = JoinBodyBuilder();
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


