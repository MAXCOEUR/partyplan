//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:partyplan_api/src/model/purchase_body_purchased_quantity.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'purchase_body.g.dart';

/// PurchaseBody
///
/// Properties:
/// * [purchasedQuantity] 
/// * [actualPrice] 
@BuiltValue()
abstract class PurchaseBody implements Built<PurchaseBody, PurchaseBodyBuilder> {
  @BuiltValueField(wireName: r'purchasedQuantity')
  PurchaseBodyPurchasedQuantity? get purchasedQuantity;

  @BuiltValueField(wireName: r'actualPrice')
  PurchaseBodyPurchasedQuantity? get actualPrice;

  PurchaseBody._();

  factory PurchaseBody([void updates(PurchaseBodyBuilder b)]) = _$PurchaseBody;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(PurchaseBodyBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<PurchaseBody> get serializer => _$PurchaseBodySerializer();
}

class _$PurchaseBodySerializer implements PrimitiveSerializer<PurchaseBody> {
  @override
  final Iterable<Type> types = const [PurchaseBody, _$PurchaseBody];

  @override
  final String wireName = r'PurchaseBody';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    PurchaseBody object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'purchasedQuantity';
    yield object.purchasedQuantity == null ? null : serializers.serialize(
      object.purchasedQuantity,
      specifiedType: const FullType.nullable(PurchaseBodyPurchasedQuantity),
    );
    yield r'actualPrice';
    yield object.actualPrice == null ? null : serializers.serialize(
      object.actualPrice,
      specifiedType: const FullType.nullable(PurchaseBodyPurchasedQuantity),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    PurchaseBody object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required PurchaseBodyBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'purchasedQuantity':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(PurchaseBodyPurchasedQuantity),
          ) as PurchaseBodyPurchasedQuantity?;
          if (valueDes == null) continue;
          result.purchasedQuantity.replace(valueDes);
          break;
        case r'actualPrice':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(PurchaseBodyPurchasedQuantity),
          ) as PurchaseBodyPurchasedQuantity?;
          if (valueDes == null) continue;
          result.actualPrice.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  PurchaseBody deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = PurchaseBodyBuilder();
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


