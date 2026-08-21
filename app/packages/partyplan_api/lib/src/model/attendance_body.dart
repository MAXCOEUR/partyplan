//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:partyplan_api/src/model/attendance_body_extra_guests.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'attendance_body.g.dart';

/// AttendanceBody
///
/// Properties:
/// * [status] 
/// * [arrivalTime] 
/// * [departureTime] 
/// * [extraGuests] 
@BuiltValue()
abstract class AttendanceBody implements Built<AttendanceBody, AttendanceBodyBuilder> {
  @BuiltValueField(wireName: r'status')
  String get status;

  @BuiltValueField(wireName: r'arrivalTime')
  String? get arrivalTime;

  @BuiltValueField(wireName: r'departureTime')
  String? get departureTime;

  @BuiltValueField(wireName: r'extraGuests')
  AttendanceBodyExtraGuests? get extraGuests;

  AttendanceBody._();

  factory AttendanceBody([void updates(AttendanceBodyBuilder b)]) = _$AttendanceBody;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(AttendanceBodyBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<AttendanceBody> get serializer => _$AttendanceBodySerializer();
}

class _$AttendanceBodySerializer implements PrimitiveSerializer<AttendanceBody> {
  @override
  final Iterable<Type> types = const [AttendanceBody, _$AttendanceBody];

  @override
  final String wireName = r'AttendanceBody';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AttendanceBody object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'status';
    yield serializers.serialize(
      object.status,
      specifiedType: const FullType(String),
    );
    yield r'arrivalTime';
    yield object.arrivalTime == null ? null : serializers.serialize(
      object.arrivalTime,
      specifiedType: const FullType.nullable(String),
    );
    yield r'departureTime';
    yield object.departureTime == null ? null : serializers.serialize(
      object.departureTime,
      specifiedType: const FullType.nullable(String),
    );
    yield r'extraGuests';
    yield object.extraGuests == null ? null : serializers.serialize(
      object.extraGuests,
      specifiedType: const FullType.nullable(AttendanceBodyExtraGuests),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    AttendanceBody object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required AttendanceBodyBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'status':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.status = valueDes;
          break;
        case r'arrivalTime':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.arrivalTime = valueDes;
          break;
        case r'departureTime':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.departureTime = valueDes;
          break;
        case r'extraGuests':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(AttendanceBodyExtraGuests),
          ) as AttendanceBodyExtraGuests?;
          if (valueDes == null) continue;
          result.extraGuests.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  AttendanceBody deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = AttendanceBodyBuilder();
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


