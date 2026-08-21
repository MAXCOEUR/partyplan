//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'update_event_body.g.dart';

/// UpdateEventBody
///
/// Properties:
/// * [name] 
/// * [description] 
/// * [startsAt] 
/// * [endsAt] 
/// * [address] 
@BuiltValue()
abstract class UpdateEventBody implements Built<UpdateEventBody, UpdateEventBodyBuilder> {
  @BuiltValueField(wireName: r'name')
  String? get name;

  @BuiltValueField(wireName: r'description')
  String? get description;

  @BuiltValueField(wireName: r'startsAt')
  DateTime? get startsAt;

  @BuiltValueField(wireName: r'endsAt')
  DateTime? get endsAt;

  @BuiltValueField(wireName: r'address')
  String? get address;

  UpdateEventBody._();

  factory UpdateEventBody([void updates(UpdateEventBodyBuilder b)]) = _$UpdateEventBody;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(UpdateEventBodyBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<UpdateEventBody> get serializer => _$UpdateEventBodySerializer();
}

class _$UpdateEventBodySerializer implements PrimitiveSerializer<UpdateEventBody> {
  @override
  final Iterable<Type> types = const [UpdateEventBody, _$UpdateEventBody];

  @override
  final String wireName = r'UpdateEventBody';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    UpdateEventBody object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'name';
    yield object.name == null ? null : serializers.serialize(
      object.name,
      specifiedType: const FullType.nullable(String),
    );
    yield r'description';
    yield object.description == null ? null : serializers.serialize(
      object.description,
      specifiedType: const FullType.nullable(String),
    );
    yield r'startsAt';
    yield object.startsAt == null ? null : serializers.serialize(
      object.startsAt,
      specifiedType: const FullType.nullable(DateTime),
    );
    yield r'endsAt';
    yield object.endsAt == null ? null : serializers.serialize(
      object.endsAt,
      specifiedType: const FullType.nullable(DateTime),
    );
    yield r'address';
    yield object.address == null ? null : serializers.serialize(
      object.address,
      specifiedType: const FullType.nullable(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    UpdateEventBody object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required UpdateEventBodyBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'name':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.name = valueDes;
          break;
        case r'description':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.description = valueDes;
          break;
        case r'startsAt':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(DateTime),
          ) as DateTime?;
          if (valueDes == null) continue;
          result.startsAt = valueDes;
          break;
        case r'endsAt':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(DateTime),
          ) as DateTime?;
          if (valueDes == null) continue;
          result.endsAt = valueDes;
          break;
        case r'address':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.address = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  UpdateEventBody deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = UpdateEventBodyBuilder();
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


