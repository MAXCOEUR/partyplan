//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:partyplan_api/src/model/admin_list_users_page_parameter.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'shopping_progress.g.dart';

/// Avancement de la liste (EF-CRS-09).
///
/// Properties:
/// * [total] 
/// * [claimed] 
/// * [purchased] 
@BuiltValue()
abstract class ShoppingProgress implements Built<ShoppingProgress, ShoppingProgressBuilder> {
  @BuiltValueField(wireName: r'total')
  AdminListUsersPageParameter get total;

  @BuiltValueField(wireName: r'claimed')
  AdminListUsersPageParameter get claimed;

  @BuiltValueField(wireName: r'purchased')
  AdminListUsersPageParameter get purchased;

  ShoppingProgress._();

  factory ShoppingProgress([void updates(ShoppingProgressBuilder b)]) = _$ShoppingProgress;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ShoppingProgressBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ShoppingProgress> get serializer => _$ShoppingProgressSerializer();
}

class _$ShoppingProgressSerializer implements PrimitiveSerializer<ShoppingProgress> {
  @override
  final Iterable<Type> types = const [ShoppingProgress, _$ShoppingProgress];

  @override
  final String wireName = r'ShoppingProgress';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ShoppingProgress object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'total';
    yield serializers.serialize(
      object.total,
      specifiedType: const FullType(AdminListUsersPageParameter),
    );
    yield r'claimed';
    yield serializers.serialize(
      object.claimed,
      specifiedType: const FullType(AdminListUsersPageParameter),
    );
    yield r'purchased';
    yield serializers.serialize(
      object.purchased,
      specifiedType: const FullType(AdminListUsersPageParameter),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ShoppingProgress object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ShoppingProgressBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'total':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(AdminListUsersPageParameter),
          ) as AdminListUsersPageParameter;
          result.total.replace(valueDes);
          break;
        case r'claimed':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(AdminListUsersPageParameter),
          ) as AdminListUsersPageParameter;
          result.claimed.replace(valueDes);
          break;
        case r'purchased':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(AdminListUsersPageParameter),
          ) as AdminListUsersPageParameter;
          result.purchased.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ShoppingProgress deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ShoppingProgressBuilder();
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


