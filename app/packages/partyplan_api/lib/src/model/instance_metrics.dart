//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:partyplan_api/src/model/admin_list_users_page_parameter.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'instance_metrics.g.dart';

/// InstanceMetrics
///
/// Properties:
/// * [totalUsers] 
/// * [suspendedUsers] 
/// * [platformStaff] 
/// * [verifiedUsers] 
/// * [totalEvents] 
/// * [activeEvents] 
/// * [guestMembers] 
@BuiltValue()
abstract class InstanceMetrics implements Built<InstanceMetrics, InstanceMetricsBuilder> {
  @BuiltValueField(wireName: r'totalUsers')
  AdminListUsersPageParameter get totalUsers;

  @BuiltValueField(wireName: r'suspendedUsers')
  AdminListUsersPageParameter get suspendedUsers;

  @BuiltValueField(wireName: r'platformStaff')
  AdminListUsersPageParameter get platformStaff;

  @BuiltValueField(wireName: r'verifiedUsers')
  AdminListUsersPageParameter get verifiedUsers;

  @BuiltValueField(wireName: r'totalEvents')
  AdminListUsersPageParameter get totalEvents;

  @BuiltValueField(wireName: r'activeEvents')
  AdminListUsersPageParameter get activeEvents;

  @BuiltValueField(wireName: r'guestMembers')
  AdminListUsersPageParameter get guestMembers;

  InstanceMetrics._();

  factory InstanceMetrics([void updates(InstanceMetricsBuilder b)]) = _$InstanceMetrics;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(InstanceMetricsBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<InstanceMetrics> get serializer => _$InstanceMetricsSerializer();
}

class _$InstanceMetricsSerializer implements PrimitiveSerializer<InstanceMetrics> {
  @override
  final Iterable<Type> types = const [InstanceMetrics, _$InstanceMetrics];

  @override
  final String wireName = r'InstanceMetrics';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    InstanceMetrics object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'totalUsers';
    yield serializers.serialize(
      object.totalUsers,
      specifiedType: const FullType(AdminListUsersPageParameter),
    );
    yield r'suspendedUsers';
    yield serializers.serialize(
      object.suspendedUsers,
      specifiedType: const FullType(AdminListUsersPageParameter),
    );
    yield r'platformStaff';
    yield serializers.serialize(
      object.platformStaff,
      specifiedType: const FullType(AdminListUsersPageParameter),
    );
    yield r'verifiedUsers';
    yield serializers.serialize(
      object.verifiedUsers,
      specifiedType: const FullType(AdminListUsersPageParameter),
    );
    yield r'totalEvents';
    yield serializers.serialize(
      object.totalEvents,
      specifiedType: const FullType(AdminListUsersPageParameter),
    );
    yield r'activeEvents';
    yield serializers.serialize(
      object.activeEvents,
      specifiedType: const FullType(AdminListUsersPageParameter),
    );
    yield r'guestMembers';
    yield serializers.serialize(
      object.guestMembers,
      specifiedType: const FullType(AdminListUsersPageParameter),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    InstanceMetrics object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required InstanceMetricsBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'totalUsers':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(AdminListUsersPageParameter),
          ) as AdminListUsersPageParameter;
          result.totalUsers.replace(valueDes);
          break;
        case r'suspendedUsers':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(AdminListUsersPageParameter),
          ) as AdminListUsersPageParameter;
          result.suspendedUsers.replace(valueDes);
          break;
        case r'platformStaff':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(AdminListUsersPageParameter),
          ) as AdminListUsersPageParameter;
          result.platformStaff.replace(valueDes);
          break;
        case r'verifiedUsers':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(AdminListUsersPageParameter),
          ) as AdminListUsersPageParameter;
          result.verifiedUsers.replace(valueDes);
          break;
        case r'totalEvents':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(AdminListUsersPageParameter),
          ) as AdminListUsersPageParameter;
          result.totalEvents.replace(valueDes);
          break;
        case r'activeEvents':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(AdminListUsersPageParameter),
          ) as AdminListUsersPageParameter;
          result.activeEvents.replace(valueDes);
          break;
        case r'guestMembers':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(AdminListUsersPageParameter),
          ) as AdminListUsersPageParameter;
          result.guestMembers.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  InstanceMetrics deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = InstanceMetricsBuilder();
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


