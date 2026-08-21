//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:partyplan_api/src/model/purchase_body_purchased_quantity.dart';
import 'package:partyplan_api/src/model/balance_view_amount.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'shopping_item_view.g.dart';

/// Article de la liste, tel que l'interface l'affiche.
///
/// Properties:
/// * [id] 
/// * [name] 
/// * [quantity] 
/// * [unit] 
/// * [category] 
/// * [assignedMemberId] 
/// * [assignedDisplayName] 
/// * [assignedToMe] 
/// * [isPurchased] 
/// * [purchasedQuantity] 
/// * [remainingQuantity] 
/// * [estimatedPrice] 
/// * [actualPrice] 
/// * [note] 
@BuiltValue()
abstract class ShoppingItemView implements Built<ShoppingItemView, ShoppingItemViewBuilder> {
  @BuiltValueField(wireName: r'id')
  String get id;

  @BuiltValueField(wireName: r'name')
  String get name;

  @BuiltValueField(wireName: r'quantity')
  BalanceViewAmount get quantity;

  @BuiltValueField(wireName: r'unit')
  String? get unit;

  @BuiltValueField(wireName: r'category')
  String get category;

  @BuiltValueField(wireName: r'assignedMemberId')
  String? get assignedMemberId;

  @BuiltValueField(wireName: r'assignedDisplayName')
  String? get assignedDisplayName;

  @BuiltValueField(wireName: r'assignedToMe')
  bool get assignedToMe;

  @BuiltValueField(wireName: r'isPurchased')
  bool get isPurchased;

  @BuiltValueField(wireName: r'purchasedQuantity')
  PurchaseBodyPurchasedQuantity? get purchasedQuantity;

  @BuiltValueField(wireName: r'remainingQuantity')
  BalanceViewAmount get remainingQuantity;

  @BuiltValueField(wireName: r'estimatedPrice')
  PurchaseBodyPurchasedQuantity? get estimatedPrice;

  @BuiltValueField(wireName: r'actualPrice')
  PurchaseBodyPurchasedQuantity? get actualPrice;

  @BuiltValueField(wireName: r'note')
  String? get note;

  ShoppingItemView._();

  factory ShoppingItemView([void updates(ShoppingItemViewBuilder b)]) = _$ShoppingItemView;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ShoppingItemViewBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ShoppingItemView> get serializer => _$ShoppingItemViewSerializer();
}

class _$ShoppingItemViewSerializer implements PrimitiveSerializer<ShoppingItemView> {
  @override
  final Iterable<Type> types = const [ShoppingItemView, _$ShoppingItemView];

  @override
  final String wireName = r'ShoppingItemView';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ShoppingItemView object, {
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
    yield r'quantity';
    yield serializers.serialize(
      object.quantity,
      specifiedType: const FullType(BalanceViewAmount),
    );
    yield r'unit';
    yield object.unit == null ? null : serializers.serialize(
      object.unit,
      specifiedType: const FullType.nullable(String),
    );
    yield r'category';
    yield serializers.serialize(
      object.category,
      specifiedType: const FullType(String),
    );
    yield r'assignedMemberId';
    yield object.assignedMemberId == null ? null : serializers.serialize(
      object.assignedMemberId,
      specifiedType: const FullType.nullable(String),
    );
    yield r'assignedDisplayName';
    yield object.assignedDisplayName == null ? null : serializers.serialize(
      object.assignedDisplayName,
      specifiedType: const FullType.nullable(String),
    );
    yield r'assignedToMe';
    yield serializers.serialize(
      object.assignedToMe,
      specifiedType: const FullType(bool),
    );
    yield r'isPurchased';
    yield serializers.serialize(
      object.isPurchased,
      specifiedType: const FullType(bool),
    );
    yield r'purchasedQuantity';
    yield object.purchasedQuantity == null ? null : serializers.serialize(
      object.purchasedQuantity,
      specifiedType: const FullType.nullable(PurchaseBodyPurchasedQuantity),
    );
    yield r'remainingQuantity';
    yield serializers.serialize(
      object.remainingQuantity,
      specifiedType: const FullType(BalanceViewAmount),
    );
    yield r'estimatedPrice';
    yield object.estimatedPrice == null ? null : serializers.serialize(
      object.estimatedPrice,
      specifiedType: const FullType.nullable(PurchaseBodyPurchasedQuantity),
    );
    yield r'actualPrice';
    yield object.actualPrice == null ? null : serializers.serialize(
      object.actualPrice,
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
    ShoppingItemView object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ShoppingItemViewBuilder result,
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
        case r'quantity':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BalanceViewAmount),
          ) as BalanceViewAmount;
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
            specifiedType: const FullType(String),
          ) as String;
          result.category = valueDes;
          break;
        case r'assignedMemberId':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.assignedMemberId = valueDes;
          break;
        case r'assignedDisplayName':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.assignedDisplayName = valueDes;
          break;
        case r'assignedToMe':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.assignedToMe = valueDes;
          break;
        case r'isPurchased':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.isPurchased = valueDes;
          break;
        case r'purchasedQuantity':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(PurchaseBodyPurchasedQuantity),
          ) as PurchaseBodyPurchasedQuantity?;
          if (valueDes == null) continue;
          result.purchasedQuantity.replace(valueDes);
          break;
        case r'remainingQuantity':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BalanceViewAmount),
          ) as BalanceViewAmount;
          result.remainingQuantity.replace(valueDes);
          break;
        case r'estimatedPrice':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(PurchaseBodyPurchasedQuantity),
          ) as PurchaseBodyPurchasedQuantity?;
          if (valueDes == null) continue;
          result.estimatedPrice.replace(valueDes);
          break;
        case r'actualPrice':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(PurchaseBodyPurchasedQuantity),
          ) as PurchaseBodyPurchasedQuantity?;
          if (valueDes == null) continue;
          result.actualPrice.replace(valueDes);
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
  ShoppingItemView deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ShoppingItemViewBuilder();
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


