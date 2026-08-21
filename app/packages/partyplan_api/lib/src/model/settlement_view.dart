//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:partyplan_api/src/model/balance_view_amount.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'settlement_view.g.dart';

/// Règlement proposé (EF-RMB-02), ou déjà effectué (EF-RMB-03).
///
/// Properties:
/// * [id] 
/// * [fromMemberId] 
/// * [fromDisplayName] 
/// * [toMemberId] 
/// * [toDisplayName] 
/// * [amount] 
/// * [done] 
/// * [involvesMe] 
@BuiltValue()
abstract class SettlementView implements Built<SettlementView, SettlementViewBuilder> {
  @BuiltValueField(wireName: r'id')
  String? get id;

  @BuiltValueField(wireName: r'fromMemberId')
  String get fromMemberId;

  @BuiltValueField(wireName: r'fromDisplayName')
  String get fromDisplayName;

  @BuiltValueField(wireName: r'toMemberId')
  String get toMemberId;

  @BuiltValueField(wireName: r'toDisplayName')
  String get toDisplayName;

  @BuiltValueField(wireName: r'amount')
  BalanceViewAmount get amount;

  @BuiltValueField(wireName: r'done')
  bool get done;

  @BuiltValueField(wireName: r'involvesMe')
  bool get involvesMe;

  SettlementView._();

  factory SettlementView([void updates(SettlementViewBuilder b)]) = _$SettlementView;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(SettlementViewBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<SettlementView> get serializer => _$SettlementViewSerializer();
}

class _$SettlementViewSerializer implements PrimitiveSerializer<SettlementView> {
  @override
  final Iterable<Type> types = const [SettlementView, _$SettlementView];

  @override
  final String wireName = r'SettlementView';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    SettlementView object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'id';
    yield object.id == null ? null : serializers.serialize(
      object.id,
      specifiedType: const FullType.nullable(String),
    );
    yield r'fromMemberId';
    yield serializers.serialize(
      object.fromMemberId,
      specifiedType: const FullType(String),
    );
    yield r'fromDisplayName';
    yield serializers.serialize(
      object.fromDisplayName,
      specifiedType: const FullType(String),
    );
    yield r'toMemberId';
    yield serializers.serialize(
      object.toMemberId,
      specifiedType: const FullType(String),
    );
    yield r'toDisplayName';
    yield serializers.serialize(
      object.toDisplayName,
      specifiedType: const FullType(String),
    );
    yield r'amount';
    yield serializers.serialize(
      object.amount,
      specifiedType: const FullType(BalanceViewAmount),
    );
    yield r'done';
    yield serializers.serialize(
      object.done,
      specifiedType: const FullType(bool),
    );
    yield r'involvesMe';
    yield serializers.serialize(
      object.involvesMe,
      specifiedType: const FullType(bool),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    SettlementView object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required SettlementViewBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.id = valueDes;
          break;
        case r'fromMemberId':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.fromMemberId = valueDes;
          break;
        case r'fromDisplayName':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.fromDisplayName = valueDes;
          break;
        case r'toMemberId':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.toMemberId = valueDes;
          break;
        case r'toDisplayName':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.toDisplayName = valueDes;
          break;
        case r'amount':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BalanceViewAmount),
          ) as BalanceViewAmount;
          result.amount.replace(valueDes);
          break;
        case r'done':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.done = valueDes;
          break;
        case r'involvesMe':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.involvesMe = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  SettlementView deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SettlementViewBuilder();
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


