/* 
 * This file is part of Stack Wallet.
 * 
 * Copyright (c) 2023 Cypher Stack
 * All Rights Reserved.
 * The code is distributed under GPLv3 license, see LICENSE file for details.
 * Generated by Cypher Stack on 2023-10-19
 *
 */

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:stackwallet/models/isar/models/blockchain_data/transaction.dart';
import 'package:stackwallet/models/isar/models/blockchain_data/v2/transaction_v2.dart';
import 'package:stackwallet/pages/wallet_view/sub_widgets/no_transactions_found.dart';
import 'package:stackwallet/pages/wallet_view/transaction_views/tx_v2/fusion_tx_group_card.dart';
import 'package:stackwallet/pages/wallet_view/transaction_views/tx_v2/transaction_v2_list_item.dart';
import 'package:stackwallet/pages/wallet_view/wallet_view.dart';
import 'package:stackwallet/providers/db/main_db_provider.dart';
import 'package:stackwallet/providers/global/wallets_provider.dart';
import 'package:stackwallet/themes/stack_colors.dart';
import 'package:stackwallet/utilities/constants.dart';
import 'package:stackwallet/utilities/util.dart';
import 'package:stackwallet/widgets/loading_indicator.dart';

class TransactionsV2List extends ConsumerStatefulWidget {
  const TransactionsV2List({
    Key? key,
    required this.walletId,
  }) : super(key: key);

  final String walletId;

  @override
  ConsumerState<TransactionsV2List> createState() => _TransactionsV2ListState();
}

class _TransactionsV2ListState extends ConsumerState<TransactionsV2List> {
  bool _hasLoaded = false;
  List<TransactionV2> _transactions = [];

  late final StreamSubscription<List<TransactionV2>> _subscription;
  late final QueryBuilder<TransactionV2, TransactionV2, QAfterSortBy> _query;

  BorderRadius get _borderRadiusFirst {
    return BorderRadius.only(
      topLeft: Radius.circular(
        Constants.size.circularBorderRadius,
      ),
      topRight: Radius.circular(
        Constants.size.circularBorderRadius,
      ),
    );
  }

  BorderRadius get _borderRadiusLast {
    return BorderRadius.only(
      bottomLeft: Radius.circular(
        Constants.size.circularBorderRadius,
      ),
      bottomRight: Radius.circular(
        Constants.size.circularBorderRadius,
      ),
    );
  }

  @override
  void initState() {
    _query = ref
        .read(mainDBProvider)
        .isar
        .transactionV2s
        .where()
        .walletIdEqualTo(widget.walletId)
        .filter()
        .not()
        .subTypeEqualTo(TransactionSubType.ethToken)
        .sortByTimestampDesc();

    _subscription = _query.watch().listen((event) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _transactions = event;
        });
      });
    });

    super.initState();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final coin = ref.watch(pWallets).getWallet(widget.walletId).info.coin;

    return FutureBuilder(
      future: _query.findAll(),
      builder: (fbContext, AsyncSnapshot<List<TransactionV2>> snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData) {
          _transactions = snapshot.data!;
          _hasLoaded = true;
        }
        if (!_hasLoaded) {
          return const Column(
            children: [
              Spacer(),
              Center(
                child: LoadingIndicator(
                  height: 50,
                  width: 50,
                ),
              ),
              Spacer(
                flex: 4,
              ),
            ],
          );
        }
        if (_transactions.isEmpty) {
          return const NoTransActionsFound();
        } else {
          _transactions.sort((a, b) {
            final compare = b.timestamp.compareTo(a.timestamp);
            if (compare == 0) {
              return b.id.compareTo(a.id);
            }
            return compare;
          });

          final List<Object> _txns = [];

          List<TransactionV2> fusions = [];

          for (int i = 0; i < _transactions.length; i++) {
            final tx = _transactions[i];

            if (tx.subType == TransactionSubType.cashFusion) {
              if (fusions.isNotEmpty) {
                final prevTime = DateTime.fromMillisecondsSinceEpoch(
                    fusions.last.timestamp * 1000);
                final thisTime =
                    DateTime.fromMillisecondsSinceEpoch(tx.timestamp * 1000);

                if (prevTime.difference(thisTime).inMinutes > 30) {
                  _txns.add(FusionTxGroup(fusions));
                  fusions = [tx];
                  continue;
                }
              }

              fusions.add(tx);
            }

            if (i + 1 < _transactions.length) {
              final nextTx = _transactions[i + 1];
              if (nextTx.subType != TransactionSubType.cashFusion &&
                  fusions.isNotEmpty) {
                _txns.add(FusionTxGroup(fusions));
                fusions = [];
              }
            }

            if (tx.subType != TransactionSubType.cashFusion) {
              _txns.add(tx);
            }
          }

          return RefreshIndicator(
            onRefresh: () async {
              await ref.read(pWallets).getWallet(widget.walletId).refresh();
            },
            child: Util.isDesktop
                ? ListView.separated(
                    shrinkWrap: true,
                    itemBuilder: (context, index) {
                      BorderRadius? radius;
                      if (_txns.length == 1) {
                        radius = BorderRadius.circular(
                          Constants.size.circularBorderRadius,
                        );
                      } else if (index == _txns.length - 1) {
                        radius = _borderRadiusLast;
                      } else if (index == 0) {
                        radius = _borderRadiusFirst;
                      }
                      final tx = _txns[index];
                      return TxListItem(
                        tx: tx,
                        coin: coin,
                        radius: radius,
                      );
                    },
                    separatorBuilder: (context, index) {
                      return Container(
                        width: double.infinity,
                        height: 2,
                        color: Theme.of(context)
                            .extension<StackColors>()!
                            .background,
                      );
                    },
                    itemCount: _txns.length,
                  )
                : ListView.builder(
                    itemCount: _txns.length,
                    itemBuilder: (context, index) {
                      BorderRadius? radius;
                      bool shouldWrap = false;
                      if (_txns.length == 1) {
                        radius = BorderRadius.circular(
                          Constants.size.circularBorderRadius,
                        );
                      } else if (index == _txns.length - 1) {
                        radius = _borderRadiusLast;
                        shouldWrap = true;
                      } else if (index == 0) {
                        radius = _borderRadiusFirst;
                      }
                      final tx = _txns[index];
                      if (shouldWrap) {
                        return Column(
                          children: [
                            TxListItem(
                              tx: tx,
                              coin: coin,
                              radius: radius,
                            ),
                            const SizedBox(
                              height: WalletView.navBarHeight + 14,
                            ),
                          ],
                        );
                      } else {
                        return TxListItem(
                          tx: tx,
                          coin: coin,
                          radius: radius,
                        );
                      }
                    },
                  ),
          );
        }
      },
    );
  }
}