//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:partyplan_api/src/model/shopping_progress.dart';
import 'package:partyplan_api/src/model/shopping_item_view.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'shopping_list.g.dart';

/// Liste de courses complète.
///
/// Properties:
/// * [progress] 
/// * [items] 
@BuiltValue()
abstract class ShoppingList implements Built<ShoppingList, ShoppingListBuilder> {
  @BuiltValueField(wireName: r'progress')
  ShoppingProgress get progress;

  @BuiltValueField(wireName: r'items')
  BuiltList<ShoppingItemView> get items;

  ShoppingList._();

  factory ShoppingList([void updates(ShoppingListBuilder b)]) = _$ShoppingList;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ShoppingListBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ShoppingList> get serializer => _$ShoppingListSerializer();
}

class _$ShoppingListSerializer implements PrimitiveSerializer<ShoppingList> {
  @override
  final Iterable<Type> types = const [ShoppingList, _$ShoppingList];

  @override
  final String wireName = r'ShoppingList';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ShoppingList object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'progress';
    yield serializers.serialize(
      object.progress,
      specifiedType: const FullType(ShoppingProgress),
    );
    yield r'items';
    yield serializers.serialize(
      object.items,
      specifiedType: const FullType(BuiltList, [FullType(ShoppingItemView)]),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ShoppingList object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ShoppingListBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'progress':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(ShoppingProgress),
          ) as ShoppingProgress;
          result.progress.replace(valueDes);
          break;
        case r'items':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(ShoppingItemView)]),
          ) as BuiltList<ShoppingItemView>;
          result.items.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ShoppingList deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ShoppingListBuilder();
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


