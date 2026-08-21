//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:partyplan_api/src/model/user_record.dart';
import 'package:built_collection/built_collection.dart';
import 'package:partyplan_api/src/model/admin_list_users_page_parameter.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'user_page.g.dart';

/// UserPage
///
/// Properties:
/// * [items] 
/// * [total] 
/// * [page] 
/// * [pageSize] 
@BuiltValue()
abstract class UserPage implements Built<UserPage, UserPageBuilder> {
  @BuiltValueField(wireName: r'items')
  BuiltList<UserRecord> get items;

  @BuiltValueField(wireName: r'total')
  AdminListUsersPageParameter get total;

  @BuiltValueField(wireName: r'page')
  AdminListUsersPageParameter get page;

  @BuiltValueField(wireName: r'pageSize')
  AdminListUsersPageParameter get pageSize;

  UserPage._();

  factory UserPage([void updates(UserPageBuilder b)]) = _$UserPage;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(UserPageBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<UserPage> get serializer => _$UserPageSerializer();
}

class _$UserPageSerializer implements PrimitiveSerializer<UserPage> {
  @override
  final Iterable<Type> types = const [UserPage, _$UserPage];

  @override
  final String wireName = r'UserPage';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    UserPage object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'items';
    yield serializers.serialize(
      object.items,
      specifiedType: const FullType(BuiltList, [FullType(UserRecord)]),
    );
    yield r'total';
    yield serializers.serialize(
      object.total,
      specifiedType: const FullType(AdminListUsersPageParameter),
    );
    yield r'page';
    yield serializers.serialize(
      object.page,
      specifiedType: const FullType(AdminListUsersPageParameter),
    );
    yield r'pageSize';
    yield serializers.serialize(
      object.pageSize,
      specifiedType: const FullType(AdminListUsersPageParameter),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    UserPage object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required UserPageBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'items':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(UserRecord)]),
          ) as BuiltList<UserRecord>;
          result.items.replace(valueDes);
          break;
        case r'total':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(AdminListUsersPageParameter),
          ) as AdminListUsersPageParameter;
          result.total.replace(valueDes);
          break;
        case r'page':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(AdminListUsersPageParameter),
          ) as AdminListUsersPageParameter;
          result.page.replace(valueDes);
          break;
        case r'pageSize':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(AdminListUsersPageParameter),
          ) as AdminListUsersPageParameter;
          result.pageSize.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  UserPage deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = UserPageBuilder();
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


