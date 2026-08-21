//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:partyplan_api/src/model/balance_view_amount.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'balance_view.g.dart';

/// Solde d'un membre, tel que l'interface l'affiche (EF-RMB-01).
///
/// Properties:
/// * [memberId] 
/// * [displayName] 
/// * [amount] 
@BuiltValue()
abstract class BalanceView implements Built<BalanceView, BalanceViewBuilder> {
  @BuiltValueField(wireName: r'memberId')
  String get memberId;

  @BuiltValueField(wireName: r'displayName')
  String get displayName;

  @BuiltValueField(wireName: r'amount')
  BalanceViewAmount get amount;

  BalanceView._();

  factory BalanceView([void updates(BalanceViewBuilder b)]) = _$BalanceView;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(BalanceViewBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<BalanceView> get serializer => _$BalanceViewSerializer();
}

class _$BalanceViewSerializer implements PrimitiveSerializer<BalanceView> {
  @override
  final Iterable<Type> types = const [BalanceView, _$BalanceView];

  @override
  final String wireName = r'BalanceView';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    BalanceView object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'memberId';
    yield serializers.serialize(
      object.memberId,
      specifiedType: const FullType(String),
    );
    yield r'displayName';
    yield serializers.serialize(
      object.displayName,
      specifiedType: const FullType(String),
    );
    yield r'amount';
    yield serializers.serialize(
      object.amount,
      specifiedType: const FullType(BalanceViewAmount),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    BalanceView object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required BalanceViewBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'memberId':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.memberId = valueDes;
          break;
        case r'displayName':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.displayName = valueDes;
          break;
        case r'amount':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BalanceViewAmount),
          ) as BalanceViewAmount;
          result.amount.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  BalanceView deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = BalanceViewBuilder();
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


