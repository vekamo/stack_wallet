/* 
 * This file is part of Stack Wallet.
 * 
 * Copyright (c) 2023 Cypher Stack
 * All Rights Reserved.
 * The code is distributed under GPLv3 license, see LICENSE file for details.
 * Generated by Cypher Stack on 2023-05-26
 *
 */

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/db/main_db_provider.dart';
import '../../../../themes/stack_colors.dart';
import '../../../../utilities/text_styles.dart';
import '../../../../wallets/isar/models/wallet_info.dart';
import '../../../../wallets/isar/providers/wallet_info_provider.dart';
import '../../../../widgets/background.dart';
import '../../../../widgets/custom_buttons/app_bar_icon_button.dart';
import '../../../../widgets/custom_buttons/draggable_switch_button.dart';

class LelantusSettingsView extends ConsumerStatefulWidget {
  const LelantusSettingsView({
    super.key,
    required this.walletId,
  });

  static const String routeName = "/lelantusSettings";

  final String walletId;

  @override
  ConsumerState<LelantusSettingsView> createState() =>
      _LelantusSettingsViewState();
}

class _LelantusSettingsViewState extends ConsumerState<LelantusSettingsView> {
  bool _isUpdatingLelantusScanning = false;

  Future<void> _switchToggled(bool newValue) async {
    if (_isUpdatingLelantusScanning) return;
    _isUpdatingLelantusScanning = true; // Lock mutex.

    try {
      // Toggle enableLelantusScanning in wallet info.
      await ref.read(pWalletInfo(widget.walletId)).updateOtherData(
        newEntries: {
          WalletInfoKeys.enableLelantusScanning: newValue,
        },
        isar: ref.read(mainDBProvider).isar,
      );
    } finally {
      // ensure _isUpdatingLelantusScanning is set to false no matter what
      _isUpdatingLelantusScanning = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Background(
      child: Scaffold(
        backgroundColor: Theme.of(context).extension<StackColors>()!.background,
        appBar: AppBar(
          leading: AppBarBackButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          title: Text(
            "Lelantus settings",
            style: STextStyles.navBarTitle(context),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  SizedBox(
                    height: 20,
                    width: 40,
                    child: DraggableSwitchButton(
                      isOn: ref.watch(
                            pWalletInfo(widget.walletId)
                                .select((value) => value.otherData),
                          )[WalletInfoKeys.enableLelantusScanning] as bool? ??
                          false,
                      onValueChanged: _switchToggled,
                    ),
                  ),
                  const SizedBox(
                    width: 16,
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Scan for Lelantus transactions",
                        style: STextStyles.smallMed12(context),
                      ),
                      // Text(
                      //   detail,
                      //   style: STextStyles.desktopTextExtraExtraSmall(context),
                      // ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
