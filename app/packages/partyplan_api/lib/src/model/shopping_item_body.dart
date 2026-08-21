//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:partyplan_api/src/model/purchase_body_purchased_quantity.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'shopping_item_body.g.dart';

/// ShoppingItemBody
///
/// Properties:
/// * [name] 
/// * [quantity] 
/// * [unit] 
/// * [category] 
/// * [estimatedPrice] 
/// * [note] 
@BuiltValue()
abstract class ShoppingItemBody implements Built<ShoppingItemBody, ShoppingItemBodyBuilder> {
  @BuiltValueField(wireName: r'name')
  String get name;

  @BuiltValueField(wireName: r'quantity')
  PurchaseBodyPurchasedQuantity? get quantity;

  @BuiltValueField(wireName: r'unit')
  String? get unit;

  @BuiltValueField(wireName: r'category')
  String? get category;

  @BuiltValueField(wireName: r'estimatedPrice')
  PurchaseBodyPurchasedQuantity? get estimatedPrice;

  @BuiltValueField(wireName: r'note')
  String? get note;

  ShoppingItemBody._();

  factory ShoppingItemBody([void updates(ShoppingItemBodyBuilder b)]) = _$ShoppingItemBody;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ShoppingItemBodyBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ShoppingItemBody> get serializer => _$ShoppingItemBodySerializer();
}

class _$ShoppingItemBodySerializer implements PrimitiveSerializer<ShoppingItemBody> {
  @override
  final Iterable<Type> types = const [ShoppingItemBody, _$ShoppingItemBody];

  @override
  final String wireName = r'ShoppingItemBody';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ShoppingItemBody object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'name';
    yield serializers.serialize(
      object.name,
      specifiedType: const FullType(String),
    );
    yield r'quantity';
    yield object.quantity == null ? null : serializers.serialize(
      object.quantity,
      specifiedType: const FullType.nullable(PurchaseBodyPurchasedQuantity),
    );
    yield r'unit';
    yield object.unit == null ? null : serializers.serialize(
      object.unit,
      specifiedType: const FullType.nullable(String),
    );
    yield r'category';
    yield object.category == null ? null : serializers.serialize(
      object.category,
      specifiedType: const FullType.nullable(String),
    );
    yield r'estimatedPrice';
    yield object.estimatedPrice == null ? null : serializers.serialize(
      object.estimatedPrice,
      specifiedType: const FullType.nullable(PurchaseBodyPurchasedQuantity),
    );
    yield r'note';
    yield object.note == null ? null : serializers.serialize(
      object.note,
      specifiedType: const FullType.nullable(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ShoppingItemBody object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ShoppingItemBodyBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'name':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.name = valueDes;
          break;
        case r'quantity':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(PurchaseBodyPurchasedQuantity),
          ) as PurchaseBodyPurchasedQuantity?;
          if (valueDes == null) continue;
          result.quantity.replace(valueDes);
          break;
        case r'unit':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.unit = valueDes;
          break;
        case r'category':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.category = valueDes;
          break;
        case r'estimatedPrice':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(PurchaseBodyPurchasedQuantity),
          ) as PurchaseBodyPurchasedQuantity?;
          if (valueDes == null) continue;
          result.estimatedPrice.replace(valueDes);
          break;
        case r'note':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.note = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ShoppingItemBody deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ShoppingItemBodyBuilder();
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


