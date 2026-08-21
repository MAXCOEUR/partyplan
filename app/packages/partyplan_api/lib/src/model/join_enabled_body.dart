//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'join_enabled_body.g.dart';

/// JoinEnabledBody
///
/// Properties:
/// * [joinEnabled] 
@BuiltValue()
abstract class JoinEnabledBody implements Built<JoinEnabledBody, JoinEnabledBodyBuilder> {
  @BuiltValueField(wireName: r'joinEnabled')
  bool get joinEnabled;

  JoinEnabledBody._();

  factory JoinEnabledBody([void updates(JoinEnabledBodyBuilder b)]) = _$JoinEnabledBody;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(JoinEnabledBodyBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<JoinEnabledBody> get serializer => _$JoinEnabledBodySerializer();
}

class _$JoinEnabledBodySerializer implements PrimitiveSerializer<JoinEnabledBody> {
  @override
  final Iterable<Type> types = const [JoinEnabledBody, _$JoinEnabledBody];

  @override
  final String wireName = r'JoinEnabledBody';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    JoinEnabledBody object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'joinEnabled';
    yield serializers.serialize(
      object.joinEnabled,
      specifiedType: const FullType(bool),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    JoinEnabledBody object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required JoinEnabledBodyBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'joinEnabled':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.joinEnabled = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  JoinEnabledBody deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = JoinEnabledBodyBuilder();
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


