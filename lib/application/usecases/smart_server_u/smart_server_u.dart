import 'dart:async';
import 'dart:io';

import 'package:cbj_smart_device/application/usecases/core_u/actions_to_preform_u.dart';
import 'package:cbj_smart_device/application/usecases/smart_device_objects_u/abstracts_devices/smart_device_base.dart';
import 'package:cbj_smart_device/application/usecases/smart_device_objects_u/abstracts_devices/smart_device_base_abstract.dart';
import 'package:cbj_smart_device/core/my_singleton.dart';
import 'package:cbj_smart_device/domain/entities/local_db_e/local_db_e.dart';
import 'package:cbj_smart_device/infrastructure/datasources/accounts_information_d/accounts_information_d.dart';
import 'package:cbj_smart_device/infrastructure/datasources/smart_server_d/smart_server_helper.dart';
import 'package:cbj_smart_device/infrastructure/gen/cbj_smart_device_server/protoc_as_dart/cbj_smart_device_server.pbgrpc.dart';
import 'package:cbj_smart_device/infrastructure/repositories/core_r/my_singleton_helper.dart';
import 'package:cbj_smart_device/utils.dart';
import 'package:grpc/grpc.dart';
import 'package:uuid/uuid.dart';

/// This class get what to execute straight from the grpc request,
class CbjSmartDeviceServerU extends CbjSmartDeviceConnectionsServiceBase {
  static const CbjDeviceStateGRPC _deviceState =
      CbjDeviceStateGRPC.waitingInComp;

  Future startLocalServer() async {
    final server = Server([CbjSmartDeviceServerU()]);
    await server.serve(port: 50054);
    logger.i('Server listening on port ${server.port}...');
  }

  ///  Listening to port and deciding what to do with the response
  void waitForConnection(
    FirebaseAccountsInformationD? firebaseAccountsInformationD,
  ) {
    logger.i('Wait for connection');

    final CbjSmartDeviceServerU smartServer = CbjSmartDeviceServerU();
    smartServer.startListen(
      firebaseAccountsInformationD,
    ); // Will go throw the model with the
    // grpc logic and converter to objects
  }

  ///  Listening in the background to incoming connections
  Future startListen(
    FirebaseAccountsInformationD? firebaseAccountsInformationD,
  ) async {
    logger.i('Start listen');

    startListenToDb(firebaseAccountsInformationD);
    await startLocalServer();
  }

  void startListenToDb(
    FirebaseAccountsInformationD? firebaseAccountInformationD,
  ) {
    logger.i('startListenToDb');

    if (firebaseAccountInformationD == null) {
      print('Database var databaseInformationFromDb is null');
      return;
    }

    if (firebaseAccountInformationD.areAllValuesNotNull()) {
      // database for this device
    }
  }

  @override
  Future<CbjCompSmartDeviceInfo> getCompInfo(
    ServiceCall call,
    CbjCommendStatus request,
  ) async {
    logger.i('Get comp info');

    final String compId = const Uuid().v1();
    final String compUuid = await MySingletonHelper.getUuid();
    final String os = MySingletonHelper.getOs();
    final String osVersion = MySingletonHelper.getOsVersion();

    final List<SmartDeviceBaseAbstract> devicesList =
        MySingleton.getSmartDevicesList();

    final CbjCompSpecs compSpecs = CbjCompSpecs(
      compId: compId,
      compUuid: compUuid,
      compOs: os,
      compModel: osVersion,
      compType: 'Personal Computer',
      pubspecYamlVersion: 'Missing',
    );

    final List<CbjSmartDeviceInfo> smartDeviceInfoList = [];

    for (var element in devicesList) {
      CbjDeviceTypes cbjDeviceTypes;

      String defaultName = element.deviceInformation.getName();

      switch (element.getDeviceType()) {
        case CbjDeviceTypes.light:
          cbjDeviceTypes = CbjDeviceTypes.light;
          break;
        case CbjDeviceTypes.blinds:
          cbjDeviceTypes = CbjDeviceTypes.blinds;
          break;
        case CbjDeviceTypes.boiler:
          cbjDeviceTypes = CbjDeviceTypes.boiler;
          break;
        case CbjDeviceTypes.smartComputer:
          cbjDeviceTypes = CbjDeviceTypes.smartComputer;
          defaultName =
              defaultName.isNotEmpty ? defaultName : 'Personal Computer';
          break;
        default:
          cbjDeviceTypes = CbjDeviceTypes.typeNotSupported;
      }

      CbjDeviceActions? dAction;
      if (element.runtimeType is SmartDeviceBase) {
        element = element as SmartDeviceBase;
        dAction = element.getDeviceState()
            ? CbjDeviceActions.on
            : CbjDeviceActions.off;
      } else {
        dAction = CbjDeviceActions.off;
      }

      final CbjDeviceTypesActions cbjDeviceTypesActions = CbjDeviceTypesActions(
        deviceType: cbjDeviceTypes,
        deviceAction: dAction,
        deviceStateGRPC: CbjDeviceStateGRPC.waitingInComp,
      );

      defaultName = defaultName.isNotEmpty ? defaultName : 'Cbj Smart Device';

      final CbjSmartDeviceInfo smartDeviceInfo = CbjSmartDeviceInfo(
        id: element.id,
        senderId: compId,
        deviceTypesActions: cbjDeviceTypesActions,
        compSpecs: compSpecs,
        defaultName: defaultName,
        senderDeviceOs: os,
        senderDeviceModel: osVersion,
      );
      smartDeviceInfoList.add(smartDeviceInfo);
    }

    final CbjCompSmartDeviceInfo compInfo = CbjCompSmartDeviceInfo(
      compSpecs: compSpecs,
      smartDevicesInComp: smartDeviceInfoList,
    );

    return Future<CbjCompSmartDeviceInfo>.value(compInfo);
  }

  //  Return the status of the specified device
  @override
  Future<CbjSmartDeviceStatus> getStatus(
    ServiceCall call,
    CbjSmartDeviceInfo request,
  ) async {
    logger.i('Get status');

    final String deviceStatus = await executeCbjDeviceActionstring(
      request,
      CbjDeviceActions.actionNotSupported,
      _deviceState,
    );

    logger.i(
      'Getting status of device $request and device status in bool $deviceStatus',
    );
    return CbjSmartDeviceStatus()..onOffState = deviceStatus == 'true';
  }

  @override
  Future<CbjCommendStatus> updateDeviceName(
    ServiceCall call,
    CbjSmartDeviceUpdateDetails request,
  ) async {
    logger.i(
      'Updating device name:${request.smartDevice.id} into: ${request.newName}',
    );
    final SmartDeviceBaseAbstract smartDevice =
        getSmartDeviceBaseAbstract(request.smartDevice)!;
    smartDevice.id = request.newName;
    final CbjCommendStatus cbjCommendStatus = CbjCommendStatus();
    cbjCommendStatus.success = true;
    final LocalDbE localDbE = LocalDbE();
    await localDbE.saveAllDevices(MySingleton.getSmartDevicesList());
    return Future<CbjCommendStatus>.value(cbjCommendStatus);
  }

  @override
  Future<CbjCommendStatus> setOffDevice(
    ServiceCall call,
    CbjSmartDeviceInfo request,
  ) async {
    logger.i('Turn device ${request.id} off');
    return executeCbjDeviceActionserver(
      request,
      CbjDeviceActions.off,
      _deviceState,
    );
  }

  @override
  Future<CbjCommendStatus> setOnDevice(
    ServiceCall call,
    CbjSmartDeviceInfo request,
  ) async {
    logger.i('Turn device ${request.id} on');
    return executeCbjDeviceActionserver(
      request,
      CbjDeviceActions.on,
      _deviceState,
    );
  }

  @override
  Future<CbjCommendStatus> setBlindsUp(
    ServiceCall call,
    CbjSmartDeviceInfo request,
  ) async {
    logger.i('Turn blinds ${request.id} up');
    return executeCbjDeviceActionserver(
      request,
      CbjDeviceActions.moveUp,
      _deviceState,
    );
  }

  @override
  Future<CbjCommendStatus> setBlindsDown(
    ServiceCall call,
    CbjSmartDeviceInfo request,
  ) async {
    logger.i('Turn blinds ${request.id} down');

    return executeCbjDeviceActionserver(
      request,
      CbjDeviceActions.moveDown,
      _deviceState,
    );
  }

  @override
  Future<CbjCommendStatus> setBlindsStop(
    ServiceCall call,
    CbjSmartDeviceInfo request,
  ) async {
    logger.i('Turn blinds ${request.id} stop');

    return executeCbjDeviceActionserver(
      request,
      CbjDeviceActions.stop,
      _deviceState,
    );
  }

  SmartDeviceBaseAbstract? getSmartDeviceBaseAbstract(
    CbjSmartDeviceInfo request,
  ) {
    logger.i('getSmartDeviceBaseAbstract');
    try {
      return MySingleton.getSmartDevicesList().firstWhere(
        (smartDeviceBaseAbstractO) => smartDeviceBaseAbstractO.id == request.id,
      );
    } catch (exception) {
      logger.e('Exception, device name ${request.id} could not be found:'
          ' ${exception.toString()}');
      return null;
    }
  }

  CbjCommendStatus executeCbjDeviceActionserver(
    CbjSmartDeviceInfo request,
    CbjDeviceActions deviceAction,
    CbjDeviceStateGRPC deviceState,
  ) {
    final SmartDeviceBaseAbstract smartDevice =
        getSmartDeviceBaseAbstract(request)!;
    if (smartDevice == null) {
      return CbjCommendStatus()..success = false;
    }

    if (smartDevice is SmartDeviceBase) {
      ActionsToPreformU.executeDeviceAction(
        smartDevice,
        deviceAction,
        deviceState,
      );
      return CbjCommendStatus()..success = smartDevice.onOff;
    }
    return CbjCommendStatus()..success = false;
  }

  Future<String> executeCbjDeviceActionstring(
    CbjSmartDeviceInfo request,
    CbjDeviceActions deviceAction,
    CbjDeviceStateGRPC deviceState,
  ) async {
    final SmartDeviceBaseAbstract? smartDevice =
        getSmartDeviceBaseAbstract(request);
    if (smartDevice == null) {
      return 'SmartDevice is null in execute CbjDeviceActions String';
    }

    if (smartDevice is SmartDeviceBase) {
      return ActionsToPreformU.executeDeviceAction(
        smartDevice,
        deviceAction,
        deviceState,
      );
    }
    return 'Error executing device action string';
  }

  @override
  Future<CbjCommendStatus> setFirebaseAccountInformation(
    ServiceCall call,
    CbjFirebaseAccountInformation request,
  ) async {
    logger.i('This is the function setCbjFirebaseAccountInformation');
    final CbjCommendStatus cbjCommendStatus =
        await setCbjFirebaseAccountInformationHelper(request);

    return Future<CbjCommendStatus>.value(cbjCommendStatus);
  }

  @override
  Future<CbjCommendStatus> setCompInfo(
    ServiceCall call,
    CbjCompSmartDeviceInfo request,
  ) async {
    logger.i('setCompInfo');

    return setCompHelper(request);
  }

  @override
  Future<CbjCommendStatus> firstSetup(
    ServiceCall call,
    CbjFirstSetupMessage request,
  ) async {
    logger.i('firstSetup');

    try {
      final CbjCompSmartDeviceInfo compInfo = request.compInfo;
      final CbjCommendStatus cbjCommendStatusSetComp =
          await setCompHelper(compInfo);

      final CbjCommendStatus cbjCommendStatusSetFirebase =
          await setCbjFirebaseAccountInformationHelper(
        request.firebaseAccountInformation,
      );

      if (cbjCommendStatusSetComp.success &&
          cbjCommendStatusSetFirebase.success) {
        return CbjCommendStatus()..success = true;
      }
    } catch (e) {
      logger.e('Error first setup');
    }

    return CbjCommendStatus()..success = false;
  }

  Future<CbjCommendStatus> setCompHelper(
    CbjCompSmartDeviceInfo compInfo,
  ) async {
    try {
      logger.i('SetCompHelper');

      final List<SmartDeviceBaseAbstract> smartDeviceList =
          MySingleton.getSmartDevicesList();

      for (final SmartDeviceBaseAbstract smartDevice in smartDeviceList) {
        for (final CbjSmartDeviceInfo smartDeviceInfo
            in compInfo.smartDevicesInComp) {
          if (smartDevice.id == smartDeviceInfo.id) {
            smartDevice.deviceInformation.setName(smartDeviceInfo.defaultName);
            break;
          }
        }
      }

      final LocalDbE localDbE = LocalDbE();
      await localDbE.saveAllDevices(MySingleton.getSmartDevicesList());

      return CbjCommendStatus()..success = true;
    } catch (e) {
      return CbjCommendStatus()..success = false;
    }
  }

  Future<CbjCommendStatus> setCbjFirebaseAccountInformationHelper(
    CbjFirebaseAccountInformation request,
  ) async {
    logger.i('setCbjFirebaseAccountInformationHelper');

    try {
      final FirebaseAccountsInformationD firebaseAccountsInformationD =
          FirebaseAccountsInformationD(
        request.fireBaseProjectId,
        request.fireBaseApiKey,
        request.userEmail,
        request.userPassword,
        request.homeId,
      );

      for (final SmartDeviceBaseAbstract device
          in MySingleton.getSmartDevicesList()) {
        if (device.getDeviceType() == CbjDeviceTypes.light) {
          final Map<String, String> dataToChange = {
            GrpcClientTypes.cbjDeviceStateGRPCTypeString:
                CbjDeviceStateGRPC.ack.toString(),
          };
        }
      }

      final LocalDbE localDbE = LocalDbE();
      localDbE.saveListOfDatabaseInformation(firebaseAccountsInformationD);

      startListenToDb(firebaseAccountsInformationD);
      exitTheApp();
      return CbjCommendStatus()..success = true;
    } catch (e) {
      return CbjCommendStatus()..success = false;
    }
  }

  Future<void> exitTheApp() async {
    const int secondsToExistTheProgram = 15;
    print('$secondsToExistTheProgram seconds to exit the program');
    await Future.delayed(const Duration(seconds: secondsToExistTheProgram));
    exit(0);
  }

  @override
  Stream<CbjRequestsAndStatusFromHub> registerClient(
    ServiceCall call,
    Stream<CbjClientStatusRequests> request,
  ) async* {
    logger.i('object registerClient now');
    yield CbjRequestsAndStatusFromHub();
  }

  @override
  Stream<CbjClientStatusRequests> registerHub(
    ServiceCall call,
    Stream<CbjRequestsAndStatusFromHub> request,
  ) async* {
    logger.i('registerHub');
    yield CbjClientStatusRequests();
  }

  @override
  Future<CbjCommendStatus> suspendComputer(
    ServiceCall call,
    CbjSmartDeviceInfo request,
  ) async {
    logger.i('Suspend computer');

    return executeCbjDeviceActionserver(
      request,
      CbjDeviceActions.suspend,
      _deviceState,
    );
  }

  @override
  Future<CbjCommendStatus> shutdownComputer(
    ServiceCall call,
    CbjSmartDeviceInfo request,
  ) async {
    logger.i('Shutdown computer');

    return executeCbjDeviceActionserver(
      request,
      CbjDeviceActions.shutdown,
      _deviceState,
    );
  }
}
