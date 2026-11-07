import 'day.dart';

/// Apps that must never be blockable, whatever the user picks. The platform
/// layer adds the device's own default dialer and SMS apps on top of these.
const neverBlockPackages = {
  'com.doordie.do_or_die',
  'com.android.settings',
  'com.android.phone',
  'com.android.dialer',
  'com.google.android.dialer',
  'com.android.contacts',
  'com.android.mms',
  'com.google.android.apps.messaging',
  'com.google.android.apps.maps',
  'com.android.emergency',
  ...bankingPackages,
};

/// Banking and UPI apps: money must stay reachable during a lock. Mirrored
/// in MainActivity.kt so they never appear in the app picker.
const bankingPackages = {
  'com.sbi.lotusintouch',
  'com.sbi.SBIFreedomPlus',
  'com.google.android.apps.nbu.paisa.user', // Google Pay
  'com.phonepe.app',
  'net.one97.paytm',
  'in.org.npci.upiapp', // BHIM
  'com.csam.icici.bank.imobile',
  'com.snapwork.hdfc',
  'com.axis.mobile',
  'com.msf.kbank.mobile', // Kotak
  'com.bankofbaroda.mconnect',
  'com.dreamplug.androidapp', // CRED
};

class BlockListVersion {
  const BlockListVersion(this.effectiveFrom, this.packages);

  final DayKey effectiveFrom;
  final Set<String> packages;
}

/// The apps the user has chosen to lock during the Penalty Zone.
///
/// Adding an app applies immediately (makes the penalty harder). Removing one
/// applies from the next day, so a lock can't be dodged after failing.
class BlockList {
  BlockList.initial(DayKey from, Set<String> packages)
    : versions = List.unmodifiable([
        BlockListVersion(from, _allowed(packages)),
      ]);

  const BlockList._(this.versions);

  /// Rebuilds a block list from saved versions.
  BlockList.fromVersions(List<BlockListVersion> versions)
    : versions = List.unmodifiable(
        [
          for (final v in versions)
            BlockListVersion(v.effectiveFrom, _allowed(v.packages)),
        ]..sort((a, b) => a.effectiveFrom.compareTo(b.effectiveFrom)),
      );

  final List<BlockListVersion> versions;

  static Set<String> _allowed(Set<String> packages) =>
      Set.unmodifiable(packages.difference(neverBlockPackages));

  Set<String> packagesOn(DayKey day) {
    BlockListVersion? current;
    for (final v in versions) {
      if (!v.effectiveFrom.isAfter(day)) current = v;
    }
    return current?.packages ?? const {};
  }

  BlockList add(DayKey today, String package) {
    if (neverBlockPackages.contains(package)) return this;
    final next = <BlockListVersion>[];
    for (final v in versions) {
      if (v.effectiveFrom.isBefore(today)) {
        next.add(v);
      } else {
        next.add(BlockListVersion(v.effectiveFrom, {...v.packages, package}));
      }
    }
    if (!next.any((v) => v.effectiveFrom == today)) {
      next.add(BlockListVersion(today, {...packagesOn(today), package}));
    }
    next.sort((a, b) => a.effectiveFrom.compareTo(b.effectiveFrom));
    return BlockList._(List.unmodifiable(next));
  }

  /// Removes [package] from [delayDays] days after [today] (1 = tomorrow).
  BlockList remove(DayKey today, String package, {int delayDays = 1}) {
    final from = today.addDays(delayDays);
    final kept = versions.where((v) => v.effectiveFrom.isBefore(from));
    return BlockList._(
      List.unmodifiable([
        ...kept,
        BlockListVersion(from, packagesOn(from).difference({package})),
      ]),
    );
  }
}
