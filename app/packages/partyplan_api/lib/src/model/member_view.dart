//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:partyplan_api/src/model/admin_list_users_page_parameter.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'member_view.g.dart';

/// Membre tel qu'il apparaît dans la liste des invités (EF-PRES-04).
///
/// Properties:
/// * [id] 
/// * [displayName] 
/// * [avatarUrl] 
/// * [status] 
/// * [arrivalTime] 
/// * [departureTime] 
/// * [extraGuests] 
/// * [role] 
/// * [hasAccount] 
/// * [isMe] 
@BuiltValue()
abstract class MemberView implements Built<MemberView, MemberViewBuilder> {
  @BuiltValueField(wireName: r'id')
  String get id;

  @BuiltValueField(wireName: r'displayName')
  String get displayName;

  @BuiltValueField(wireName: r'avatarUrl')
  String? get avatarUrl;

  @BuiltValueField(wireName: r'status')
  String get status;

  @BuiltValueField(wireName: r'arrivalTime')
  String? get arrivalTime;

  @BuiltValueField(wireName: r'departureTime')
  String? get departureTime;

  @BuiltValueField(wireName: r'extraGuests')
  AdminListUsersPageParameter get extraGuests;

  @BuiltValueField(wireName: r'role')
  String get role;

  @BuiltValueField(wireName: r'hasAccount')
  bool get hasAccount;

  @BuiltValueField(wireName: r'isMe')
  bool get isMe;

  MemberView._();

  factory MemberView([void updates(MemberViewBuilder b)]) = _$MemberView;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(MemberViewBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<MemberView> get serializer => _$MemberViewSerializer();
}

class _$MemberViewSerializer implements PrimitiveSerializer<MemberView> {
  @override
  final Iterable<Type> types = const [MemberView, _$MemberView];

  @override
  final String wireName = r'MemberView';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    MemberView object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'id';
    yield serializers.serialize(
      object.id,
      specifiedType: const FullType(String),
    );
    yield r'displayName';
    yield serializers.serialize(
      object.displayName,
      specifiedType: const FullType(String),
    );
    yield r'avatarUrl';
    yield object.avatarUrl == null ? null : serializers.serialize(
      object.avatarUrl,
      specifiedType: const FullType.nullable(String),
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
    yield r'departureTime';
    yield object.departureTime == null ? null : serializers.serialize(
      object.departureTime,
      specifiedType: const FullType.nullable(String),
    );
    yield r'extraGuests';
    yield serializers.serialize(
      object.extraGuests,
      specifiedType: const FullType(AdminListUsersPageParameter),
    );
    yield r'role';
    yield serializers.serialize(
      object.role,
      specifiedType: const FullType(String),
    );
    yield r'hasAccount';
    yield serializers.serialize(
      object.hasAccount,
      specifiedType: const FullType(bool),
    );
    yield r'isMe';
    yield serializers.serialize(
      object.isMe,
      specifiedType: const FullType(bool),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    MemberView object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required MemberViewBuilder result,
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
        case r'displayName':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.displayName = valueDes;
          break;
        case r'avatarUrl':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.avatarUrl = valueDes;
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
        case r'departureTime':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.departureTime = valueDes;
          break;
        case r'extraGuests':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(AdminListUsersPageParameter),
          ) as AdminListUsersPageParameter;
          result.extraGuests.replace(valueDes);
          break;
        case r'role':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.role = valueDes;
          break;
        case r'hasAccount':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.hasAccount = valueDes;
          break;
        case r'isMe':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.isMe = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  MemberView deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = MemberViewBuilder();
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


