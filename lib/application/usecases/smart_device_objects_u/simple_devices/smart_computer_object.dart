import 'package:cbj_smart_device/application/usecases/smart_device_objects_u/abstracts_devices/smart_device_simple_abstract.dart';
import 'package:cbj_smart_device/infrastructure/gen/cbj_smart_device_server/protoc_as_dart/cbj_smart_device_server.pbgrpc.dart';
import 'package:cbj_smart_device/utils.dart';

class SmartComputerObject extends SmartDeviceSimpleAbstract {
  SmartComputerObject(
    String? uuid,
    String? smartInstanceName,
  ) : super(
          uuid,
          smartInstanceName,
          null,
          onOffButtonPinNumber: null,
        ) {
    setDeviceType(CbjDeviceTypes.smartComputer);
    logger.i('New smart computer object');
  }

  @override
  List<String> getNeededPinTypesList() => <String>[];

  @override
  static List<String> neededPinTypesList() => <String>[];

  ///  Return smart device type
  @override
  CbjDeviceTypes getDeviceType() => CbjDeviceTypes.smartComputer;

  @override
  Future<String> executeActionString(
    String wishString,
    CbjDeviceStateGRPC deviceState,
  ) async {
    final CbjDeviceActions deviceAction =
        convertWishStringToWishesObject(wishString)!;
    return executeDeviceAction(deviceAction, deviceState);
  }

  @override
  Future<String> executeDeviceAction(
    CbjDeviceActions deviceAction,
    CbjDeviceStateGRPC deviceState,
  ) async {
    return wishInSimpleClass(deviceAction, deviceState);
  }
}
