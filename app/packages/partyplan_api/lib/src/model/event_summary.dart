//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:partyplan_api/src/model/admin_list_users_page_parameter.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'event_summary.g.dart';

/// Vue de synthèse d'un événement, telle que renvoyée par l'API. Type distinct de l'entité : le contrat public ne doit pas suivre mécaniquement le schéma de la base.
///
/// Properties:
/// * [id] 
/// * [name] 
/// * [description] 
/// * [startsAt] 
/// * [endsAt] 
/// * [address] 
/// * [coverImageUrl] 
/// * [memberCount] 
/// * [presentCount] 
/// * [maybeCount] 
/// * [joinEnabled] 
@BuiltValue()
abstract class EventSummary implements Built<EventSummary, EventSummaryBuilder> {
  @BuiltValueField(wireName: r'id')
  String get id;

  @BuiltValueField(wireName: r'name')
  String get name;

  @BuiltValueField(wireName: r'description')
  String? get description;

  @BuiltValueField(wireName: r'startsAt')
  DateTime get startsAt;

  @BuiltValueField(wireName: r'endsAt')
  DateTime? get endsAt;

  @BuiltValueField(wireName: r'address')
  String? get address;

  @BuiltValueField(wireName: r'coverImageUrl')
  String? get coverImageUrl;

  @BuiltValueField(wireName: r'memberCount')
  AdminListUsersPageParameter get memberCount;

  @BuiltValueField(wireName: r'presentCount')
  AdminListUsersPageParameter get presentCount;

  @BuiltValueField(wireName: r'maybeCount')
  AdminListUsersPageParameter get maybeCount;

  @BuiltValueField(wireName: r'joinEnabled')
  bool get joinEnabled;

  EventSummary._();

  factory EventSummary([void updates(EventSummaryBuilder b)]) = _$EventSummary;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(EventSummaryBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<EventSummary> get serializer => _$EventSummarySerializer();
}

class _$EventSummarySerializer implements PrimitiveSerializer<EventSummary> {
  @override
  final Iterable<Type> types = const [EventSummary, _$EventSummary];

  @override
  final String wireName = r'EventSummary';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    EventSummary object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'id';
    yield serializers.serialize(
      object.id,
      specifiedType: const FullType(String),
    );
    yield r'name';
    yield serializers.serialize(
      object.name,
      specifiedType: const FullType(String),
    );
    yield r'description';
    yield object.description == null ? null : serializers.serialize(
      object.description,
      specifiedType: const FullType.nullable(String),
    );
    yield r'startsAt';
    yield serializers.serialize(
      object.startsAt,
      specifiedType: const FullType(DateTime),
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
    yield r'coverImageUrl';
    yield object.coverImageUrl == null ? null : serializers.serialize(
      object.coverImageUrl,
      specifiedType: const FullType.nullable(String),
    );
    yield r'memberCount';
    yield serializers.serialize(
      object.memberCount,
      specifiedType: const FullType(AdminListUsersPageParameter),
    );
    yield r'presentCount';
    yield serializers.serialize(
      object.presentCount,
      specifiedType: const FullType(AdminListUsersPageParameter),
    );
    yield r'maybeCount';
    yield serializers.serialize(
      object.maybeCount,
      specifiedType: const FullType(AdminListUsersPageParameter),
    );
    yield r'joinEnabled';
    yield serializers.serialize(
      object.joinEnabled,
      specifiedType: const FullType(bool),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    EventSummary object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required EventSummaryBuilder result,
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
        case r'name':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
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
            specifiedType: const FullType(DateTime),
          ) as DateTime;
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
        case r'coverImageUrl':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.coverImageUrl = valueDes;
          break;
        case r'memberCount':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(AdminListUsersPageParameter),
          ) as AdminListUsersPageParameter;
          result.memberCount.replace(valueDes);
          break;
        case r'presentCount':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(AdminListUsersPageParameter),
          ) as AdminListUsersPageParameter;
          result.presentCount.replace(valueDes);
          break;
        case r'maybeCount':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(AdminListUsersPageParameter),
          ) as AdminListUsersPageParameter;
          result.maybeCount.replace(valueDes);
          break;
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
  EventSummary deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = EventSummaryBuilder();
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


