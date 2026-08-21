//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:partyplan_api/src/model/admin_list_users_page_parameter.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'event_list_item.g.dart';

/// Événement tel qu'il apparaît dans la liste d'accueil (EF-EVT-05).
///
/// Properties:
/// * [id] 
/// * [name] 
/// * [startsAt] 
/// * [endsAt] 
/// * [address] 
/// * [coverImageUrl] 
/// * [invited] 
/// * [present] 
/// * [myRole] 
/// * [myStatus] 
/// * [isPast] 
@BuiltValue()
abstract class EventListItem implements Built<EventListItem, EventListItemBuilder> {
  @BuiltValueField(wireName: r'id')
  String get id;

  @BuiltValueField(wireName: r'name')
  String get name;

  @BuiltValueField(wireName: r'startsAt')
  DateTime get startsAt;

  @BuiltValueField(wireName: r'endsAt')
  DateTime? get endsAt;

  @BuiltValueField(wireName: r'address')
  String? get address;

  @BuiltValueField(wireName: r'coverImageUrl')
  String? get coverImageUrl;

  @BuiltValueField(wireName: r'invited')
  AdminListUsersPageParameter get invited;

  @BuiltValueField(wireName: r'present')
  AdminListUsersPageParameter get present;

  @BuiltValueField(wireName: r'myRole')
  String get myRole;

  @BuiltValueField(wireName: r'myStatus')
  String get myStatus;

  @BuiltValueField(wireName: r'isPast')
  bool get isPast;

  EventListItem._();

  factory EventListItem([void updates(EventListItemBuilder b)]) = _$EventListItem;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(EventListItemBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<EventListItem> get serializer => _$EventListItemSerializer();
}

class _$EventListItemSerializer implements PrimitiveSerializer<EventListItem> {
  @override
  final Iterable<Type> types = const [EventListItem, _$EventListItem];

  @override
  final String wireName = r'EventListItem';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    EventListItem object, {
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
    yield r'invited';
    yield serializers.serialize(
      object.invited,
      specifiedType: const FullType(AdminListUsersPageParameter),
    );
    yield r'present';
    yield serializers.serialize(
      object.present,
      specifiedType: const FullType(AdminListUsersPageParameter),
    );
    yield r'myRole';
    yield serializers.serialize(
      object.myRole,
      specifiedType: const FullType(String),
    );
    yield r'myStatus';
    yield serializers.serialize(
      object.myStatus,
      specifiedType: const FullType(String),
    );
    yield r'isPast';
    yield serializers.serialize(
      object.isPast,
      specifiedType: const FullType(bool),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    EventListItem object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required EventListItemBuilder result,
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
        case r'invited':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(AdminListUsersPageParameter),
          ) as AdminListUsersPageParameter;
          result.invited.replace(valueDes);
          break;
        case r'present':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(AdminListUsersPageParameter),
          ) as AdminListUsersPageParameter;
          result.present.replace(valueDes);
          break;
        case r'myRole':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.myRole = valueDes;
          break;
        case r'myStatus':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.myStatus = valueDes;
          break;
        case r'isPast':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.isPast = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  EventListItem deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = EventListItemBuilder();
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


