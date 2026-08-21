//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'audit_entry_view.g.dart';

/// Entrée du journal d'audit, telle que présentée dans le back-office.
///
/// Properties:
/// * [id] 
/// * [actorEmail] 
/// * [targetUserId] 
/// * [action] 
/// * [reason] 
/// * [ipAddress] 
/// * [createdAt] 
@BuiltValue()
abstract class AuditEntryView implements Built<AuditEntryView, AuditEntryViewBuilder> {
  @BuiltValueField(wireName: r'id')
  String get id;

  @BuiltValueField(wireName: r'actorEmail')
  String get actorEmail;

  @BuiltValueField(wireName: r'targetUserId')
  String? get targetUserId;

  @BuiltValueField(wireName: r'action')
  String get action;

  @BuiltValueField(wireName: r'reason')
  String? get reason;

  @BuiltValueField(wireName: r'ipAddress')
  String? get ipAddress;

  @BuiltValueField(wireName: r'createdAt')
  DateTime get createdAt;

  AuditEntryView._();

  factory AuditEntryView([void updates(AuditEntryViewBuilder b)]) = _$AuditEntryView;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(AuditEntryViewBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<AuditEntryView> get serializer => _$AuditEntryViewSerializer();
}

class _$AuditEntryViewSerializer implements PrimitiveSerializer<AuditEntryView> {
  @override
  final Iterable<Type> types = const [AuditEntryView, _$AuditEntryView];

  @override
  final String wireName = r'AuditEntryView';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AuditEntryView object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'id';
    yield serializers.serialize(
      object.id,
      specifiedType: const FullType(String),
    );
    yield r'actorEmail';
    yield serializers.serialize(
      object.actorEmail,
      specifiedType: const FullType(String),
    );
    yield r'targetUserId';
    yield object.targetUserId == null ? null : serializers.serialize(
      object.targetUserId,
      specifiedType: const FullType.nullable(String),
    );
    yield r'action';
    yield serializers.serialize(
      object.action,
      specifiedType: const FullType(String),
    );
    yield r'reason';
    yield object.reason == null ? null : serializers.serialize(
      object.reason,
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
  }

  @override
  Object serialize(
    Serializers serializers,
    AuditEntryView object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required AuditEntryViewBuilder result,
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
        case r'actorEmail':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.actorEmail = valueDes;
          break;
        case r'targetUserId':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.targetUserId = valueDes;
          break;
        case r'action':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.action = valueDes;
          break;
        case r'reason':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.reason = valueDes;
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
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  AuditEntryView deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = AuditEntryViewBuilder();
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


