/* 
 * This file is part of Stack Wallet.
 * 
 * Copyright (c) 2023 Cypher Stack
 * All Rights Reserved.
 * The code is distributed under GPLv3 license, see LICENSE file for details.
 * Generated by Cypher Stack on 2023-05-26
 *
 */

import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:isar/isar.dart';
import 'package:tuple/tuple.dart';

import '../../../../models/isar/models/isar_models.dart';
import '../../../../models/keys/view_only_wallet_data.dart';
import '../../../../notifications/show_flush_bar.dart';
import '../../../../pages/receive_view/generate_receiving_uri_qr_code_view.dart';
import '../../../../providers/db/main_db_provider.dart';
import '../../../../providers/providers.dart';
import '../../../../route_generator.dart';
import '../../../../themes/stack_colors.dart';
import '../../../../utilities/address_utils.dart';
import '../../../../utilities/amount/amount.dart';
import '../../../../utilities/assets.dart';
import '../../../../utilities/clipboard_interface.dart';
import '../../../../utilities/constants.dart';
import '../../../../utilities/enums/derive_path_type_enum.dart';
import '../../../../utilities/enums/txs_method_mwc_enum.dart';
import '../../../../utilities/logger.dart';
import '../../../../utilities/text_styles.dart';
import '../../../../utilities/util.dart';
import '../../../../wallets/crypto_currency/crypto_currency.dart';
import '../../../../wallets/isar/providers/eth/current_token_wallet_provider.dart';
import '../../../../wallets/isar/providers/wallet_info_provider.dart';
import '../../../../wallets/wallet/impl/bitcoin_wallet.dart';
import '../../../../wallets/wallet/impl/mimblewimblecoin_wallet.dart';
import '../../../../wallets/wallet/intermediate/bip39_hd_wallet.dart';
import '../../../../wallets/wallet/wallet_mixin_interfaces/bcash_interface.dart';
import '../../../../wallets/wallet/wallet_mixin_interfaces/extended_keys_interface.dart';
import '../../../../wallets/wallet/wallet_mixin_interfaces/multi_address_interface.dart';
import '../../../../wallets/wallet/wallet_mixin_interfaces/spark_interface.dart';
import '../../../../wallets/wallet/wallet_mixin_interfaces/view_only_option_interface.dart';
import '../../../../widgets/conditional_parent.dart';
import '../../../../widgets/desktop/primary_button.dart';
import '../../../../widgets/icon_widgets/clipboard_icon.dart';
import '../../../../widgets/icon_widgets/x_icon.dart';
import '../../../../widgets/stack_text_field.dart';
import '../../../../widgets/textfield_icon_button.dart';
import '../../../../widgets/toggle.dart';
import '../../../../widgets/custom_buttons/app_bar_icon_button.dart';
import '../../../../widgets/custom_loading_overlay.dart';
import '../../../../widgets/desktop/desktop_dialog.dart';
import '../../../../widgets/desktop/secondary_button.dart';
import '../../../../widgets/qr.dart';
import '../../../../widgets/rounded_white_container.dart';
import 'desktop_mwc_txs_method_toggle.dart';

class DesktopFinalize extends ConsumerStatefulWidget {
  const DesktopFinalize({
    super.key,
    required this.walletId,
    this.contractAddress,
    this.clipboard = const ClipboardWrapper(),
  });

  final String walletId;
  final String? contractAddress;
  final ClipboardInterface clipboard;

  @override
  ConsumerState<DesktopFinalize> createState() => _DesktopFinalizeState();
}

class _DesktopFinalizeState extends ConsumerState<DesktopFinalize> {
  late final CryptoCurrency coin;
  late final String walletId;
  late final ClipboardInterface clipboard;
  late final bool supportsSpark;
  late final bool showMultiType;
  late final bool isMimblewimblecoin;
  late TextEditingController receiveSlateController;
  String? _address;
  bool _addressToggleFlag = false;
  final _addressFocusNode = FocusNode();

  int _currentIndex = 0;
  String? _selectedMethodMwc; // Variable to store selected dropdown value
  String? _note;

  final List<AddressType> _walletAddressTypes = [];
  final Map<AddressType, String> _addressMap = {};
  final Map<AddressType, StreamSubscription<Address?>> _addressSubMap = {};

  
  
  Future<void> pasteAddress() async {
    final ClipboardData? data = await clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      String content = data.text!.trim();
      if (content.contains("\n")) {
        content = content.substring(0, content.indexOf("\n"));
      }

      try {
        final paymentData = AddressUtils.parsePaymentUri(
          content,
          logging: Logging.instance,
        );
        if (paymentData != null &&
            paymentData.coin?.uriScheme == coin.uriScheme) {
          _address = paymentData.address;
          receiveSlateController.text = _address!;
          setState(() {
            _addressToggleFlag = receiveSlateController.text.isNotEmpty;
          });
        } else {
          content = content.split("\n").first.trim();
          if (coin is Mimblewimblecoin) {
            content = AddressUtils().formatAddressMwc(content);
          }

          receiveSlateController.text = content;
          _address = content;

          //_setValidAddressProviders(_address);
          setState(() {
            _addressToggleFlag = receiveSlateController.text.isNotEmpty;
          });
        }
      } catch (e) {
        if (coin is Mimblewimblecoin) {
          // strip http:// and https:// if content contains @
          content = AddressUtils().formatAddressMwc(content);
        }
        receiveSlateController.text = content;
        _address = content;
        // Trigger validation after pasting.
        //_setValidAddressProviders(_address);
        setState(() {
          _addressToggleFlag = receiveSlateController.text.isNotEmpty;
        });
      }
    }
  }
  

  @override
  void initState() {
    receiveSlateController = TextEditingController();
    walletId = widget.walletId;
    coin = ref.read(pWalletInfo(walletId)).coin;
    clipboard = widget.clipboard;
    final wallet = ref.read(pWallets).getWallet(walletId);
    supportsSpark = ref.read(pWallets).getWallet(walletId) is SparkInterface;
    
    isMimblewimblecoin = wallet is MimblewimblecoinWallet;
    if (isMimblewimblecoin) {
      _selectedMethodMwc = "Slatepack";
    }
    debugPrint("Address generated: $isMimblewimblecoin");
    

    if (wallet is ViewOnlyOptionInterface && wallet.isViewOnly) {
      showMultiType = false;
    } else {
      showMultiType = supportsSpark ||
          (wallet is! BCashInterface &&
              wallet is Bip39HDWallet &&
              wallet.supportedAddressTypes.length > 1);
    }

    _walletAddressTypes.add(wallet.info.mainAddressType);

    if (showMultiType) {
      if (supportsSpark) {
        _walletAddressTypes.insert(0, AddressType.spark);
      } else {
        _walletAddressTypes.addAll(
          (wallet as Bip39HDWallet)
              .supportedAddressTypes
              .where((e) => e != wallet.info.mainAddressType),
        );
      }
    }

    if (_walletAddressTypes.length > 1 && wallet is BitcoinWallet) {
      _walletAddressTypes.removeWhere((e) => e == AddressType.p2pkh);
    }

    _addressMap[_walletAddressTypes[_currentIndex]] =
        ref.read(pWalletReceivingAddress(walletId));

    if (showMultiType) {
      for (final type in _walletAddressTypes) {
        _addressSubMap[type] = ref
            .read(mainDBProvider)
            .isar
            .addresses
            .where()
            .walletIdEqualTo(walletId)
            .filter()
            .typeEqualTo(type)
            .sortByDerivationIndexDesc()
            .findFirst()
            .asStream()
            .listen((event) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _addressMap[type] =
                    event?.value ?? _addressMap[type] ?? "[No address yet]";
              });
            }
          });
        });
      }
    }

    super.initState();
  }

  @override
  void dispose() {
    for (final subscription in _addressSubMap.values) {
      subscription.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("BUILD: $runtimeType");

    final String address;
    if (showMultiType) {
      address = _addressMap[_walletAddressTypes[_currentIndex]]!;
    } else {
      address = ref.watch(pWalletReceivingAddress(walletId));
    }

    final wallet = ref.watch(pWallets.select((value) => value.getWallet(walletId)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
       const SizedBox(
         height: 4,
       ),
        const SizedBox(
          height: 20,
        ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Label Text
              Text(
                "Finalize Slatepack",
                style: STextStyles.desktopTextExtraSmall(context).copyWith(
                  color: Theme.of(context)
                      .extension<StackColors>()!
                      .textFieldActiveSearchIconRight,
                ),
                textAlign: TextAlign.left,
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(
                  Constants.size.circularBorderRadius,
                ),
                child: TextField(
                  minLines: 1,
                  maxLines: 5,
                  key: const Key("sendViewAddressFieldKey"),
                  controller: receiveSlateController,
                  readOnly: false,
                  autocorrect: false,
                  enableSuggestions: false,
                  toolbarOptions: const ToolbarOptions(
                    copy: false,
                    cut: false,
                    paste: true,
                    selectAll: false,
                  ),
                  onChanged: (newValue) {
                    _address = newValue;
                    //_setValidAddressProviders(_address);

                    setState(() {
                      _addressToggleFlag = newValue.isNotEmpty;
                    });
                  },
                  focusNode: _addressFocusNode,
                  style: STextStyles.desktopTextExtraSmall(context).copyWith(
                    color: Theme.of(context)
                        .extension<StackColors>()!
                        .textFieldActiveText,
                    height: 1.8,
                  ),
                  decoration: standardInputDecoration(
                    "Enter Final Slatepack Message",
                    _addressFocusNode,
                    context,
                    desktopMed: true,
                  ).copyWith(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12, // Adjust vertical padding for better alignment
                    ),
                    suffixIcon: Padding(
                      padding: receiveSlateController.text.isEmpty
                          ? const EdgeInsets.only(right: 8)
                          : const EdgeInsets.only(right: 0),
                      child: UnconstrainedBox(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _addressToggleFlag
                                ? TextFieldIconButton(
                                    key: const Key("sendViewClearAddressFieldButtonKey"),
                                    onTap: () {
                                      receiveSlateController.text = "";
                                      _address = "";
                                      setState(() {
                                        _addressToggleFlag = false;
                                      });
                                    },
                                    child: const XIcon(),
                                  )
                                : TextFieldIconButton(
                                    key: const Key(
                                      "sendViewPasteAddressFieldButtonKey",
                                    ),
                                    onTap: pasteAddress,
                                    child: receiveSlateController.text.isEmpty
                                        ? const ClipboardIcon()
                                        : const XIcon(),
                                  ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(
          height: 32,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: PrimaryButton(
            buttonHeight: ButtonHeight.l,
            label: "Preview Receive Slatepack",
            enabled: true,
            onPressed: () {
              debugPrint('Submit button pressed for Mimblewimblecoin Slatepack');
            },
          ),
        )
      ],
    );
  }
}

