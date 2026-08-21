//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:partyplan_api/src/model/balance_view.dart';
import 'package:built_collection/built_collection.dart';
import 'package:partyplan_api/src/model/balance_view_amount.dart';
import 'package:partyplan_api/src/model/settlement_view.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'settlements_page.g.dart';

/// Vue complète des remboursements. bool SettlementsPage.InvariantHolds est faux lorsque la somme des soldes n'est pas nulle (IV-02). L'interface le signale au lieu d'afficher des chiffres qu'on sait faux (RG-RMB-04).
///
/// Properties:
/// * [balances] 
/// * [proposed] 
/// * [done] 
/// * [myBalance] 
/// * [invariantHolds] 
@BuiltValue()
abstract class SettlementsPage implements Built<SettlementsPage, SettlementsPageBuilder> {
  @BuiltValueField(wireName: r'balances')
  BuiltList<BalanceView> get balances;

  @BuiltValueField(wireName: r'proposed')
  BuiltList<SettlementView> get proposed;

  @BuiltValueField(wireName: r'done')
  BuiltList<SettlementView> get done;

  @BuiltValueField(wireName: r'myBalance')
  BalanceViewAmount get myBalance;

  @BuiltValueField(wireName: r'invariantHolds')
  bool get invariantHolds;

  SettlementsPage._();

  factory SettlementsPage([void updates(SettlementsPageBuilder b)]) = _$SettlementsPage;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(SettlementsPageBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<SettlementsPage> get serializer => _$SettlementsPageSerializer();
}

class _$SettlementsPageSerializer implements PrimitiveSerializer<SettlementsPage> {
  @override
  final Iterable<Type> types = const [SettlementsPage, _$SettlementsPage];

  @override
  final String wireName = r'SettlementsPage';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    SettlementsPage object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'balances';
    yield serializers.serialize(
      object.balances,
      specifiedType: const FullType(BuiltList, [FullType(BalanceView)]),
    );
    yield r'proposed';
    yield serializers.serialize(
      object.proposed,
      specifiedType: const FullType(BuiltList, [FullType(SettlementView)]),
    );
    yield r'done';
    yield serializers.serialize(
      object.done,
      specifiedType: const FullType(BuiltList, [FullType(SettlementView)]),
    );
    yield r'myBalance';
    yield serializers.serialize(
      object.myBalance,
      specifiedType: const FullType(BalanceViewAmount),
    );
    yield r'invariantHolds';
    yield serializers.serialize(
      object.invariantHolds,
      specifiedType: const FullType(bool),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    SettlementsPage object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required SettlementsPageBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'balances':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(BalanceView)]),
          ) as BuiltList<BalanceView>;
          result.balances.replace(valueDes);
          break;
        case r'proposed':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(SettlementView)]),
          ) as BuiltList<SettlementView>;
          result.proposed.replace(valueDes);
          break;
        case r'done':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(SettlementView)]),
          ) as BuiltList<SettlementView>;
          result.done.replace(valueDes);
          break;
        case r'myBalance':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BalanceViewAmount),
          ) as BalanceViewAmount;
          result.myBalance.replace(valueDes);
          break;
        case r'invariantHolds':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.invariantHolds = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  SettlementsPage deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SettlementsPageBuilder();
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


