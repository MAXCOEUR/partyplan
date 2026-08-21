//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'my_session.g.dart';

/// Session active, telle que présentée à son titulaire (EF-AUTH-10).
///
/// Properties:
/// * [id] 
/// * [deviceLabel] 
/// * [ipAddress] 
/// * [createdAt] 
/// * [lastSeenAt] 
/// * [isCurrent] 
@BuiltValue()
abstract class MySession implements Built<MySession, MySessionBuilder> {
  @BuiltValueField(wireName: r'id')
  String get id;

  @BuiltValueField(wireName: r'deviceLabel')
  String? get deviceLabel;

  @BuiltValueField(wireName: r'ipAddress')
  String? get ipAddress;

  @BuiltValueField(wireName: r'createdAt')
  DateTime get createdAt;

  @BuiltValueField(wireName: r'lastSeenAt')
  DateTime get lastSeenAt;

  @BuiltValueField(wireName: r'isCurrent')
  bool get isCurrent;

  MySession._();

  factory MySession([void updates(MySessionBuilder b)]) = _$MySession;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(MySessionBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<MySession> get serializer => _$MySessionSerializer();
}

class _$MySessionSerializer implements PrimitiveSerializer<MySession> {
  @override
  final Iterable<Type> types = const [MySession, _$MySession];

  @override
  final String wireName = r'MySession';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    MySession object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'id';
    yield serializers.serialize(
      object.id,
      specifiedType: const FullType(String),
    );
    yield r'deviceLabel';
    yield object.deviceLabel == null ? null : serializers.serialize(
      object.deviceLabel,
      specifiedType: const FullType.nullable(String),
    );
    yield r'ipAddress';
    yield object.ipAddress == null ? null : serializers.serialize(
      object.ipAddress,
      specifiedType: const FullType.nullable(String),
    );
    yield r'createdAt';
    yield serializers.serialize(
      object.createdAt,
      specifiedType: const FullType(DateTime),
    );
    yield r'lastSeenAt';
    yield serializers.serialize(
      object.lastSeenAt,
      specifiedType: const FullType(DateTime),
    );
    yield r'isCurrent';
    yield serializers.serialize(
      object.isCurrent,
      specifiedType: const FullType(bool),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    MySession object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required MySessionBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.id = valueDes;
          break;
        case r'deviceLabel':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.deviceLabel = valueDes;
          break;
        case r'ipAddress':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.ipAddress = valueDes;
          break;
        case r'createdAt':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.createdAt = valueDes;
          break;
        case r'lastSeenAt':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.lastSeenAt = valueDes;
          break;
        case r'isCurrent':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.isCurrent = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  MySession deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = MySessionBuilder();
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


