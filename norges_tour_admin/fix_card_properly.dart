import 'dart:io';

void main() {
  final file = File('lib/tournament_control_page.dart');
  var text = file.readAsStringSync();
  
  // Revert back to b28d3f3 just to be absolutely sure, and re-apply everything from scratch
  // Actually no, that takes too long. Let's just fix the end of _buildScheduleCard
  
  int s = text.indexOf("    final Widget qrBox = isPending");
  int e = text.indexOf("  //  UI shell ");
  if (s != -1 && e != -1) {
    text = text.replaceRange(s, e, """    final Widget qrBox = isPending
        ? SizedBox(width: 108, child: Center(child: Text('QR nr lagene\\ner klare', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: AppColors.adminTextSecondary))))
        : InkWell(
            onTap: () => _showQrDialog(matchDoc.id, teamA, teamB),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.adminSurfaceElevated)),
                    child: QrImageView(data: qrUrl, version: QrVersions.auto, size: 92, padding: EdgeInsets.zero, backgroundColor: Colors.white),
                  ),
                  const SizedBox(height: 3),
                  const Text('Scan for dommer', style: TextStyle(fontSize: 10, color: AppColors.adminTextSecondary)),
                ],
              ),
            ),
          );

    return GestureDetector(
      onTap: () => _showMatchEditDialog(matchDoc),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.adminSurfaceElevated.withOpacity(0.4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isLive ? AppColors.coral.withOpacity(0.6) : isFinished ? AppColors.green.withOpacity(0.25) : AppColors.adminSurfaceElevated, width: isLive ? 1.5 : 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 170,
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
              decoration: BoxDecoration(border: Border(left: BorderSide(color: accent, width: 4))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(children: [
                    if (matchNum != null) ...[Text('#\$matchNum', style: const TextStyle(fontSize: 12, color: AppColors.adminPrimary, fontWeight: FontWeight.bold)), const SizedBox(width: 6)],
                    Flexible(child: infoChip(statusLabel, color: statusColor)),
                    const SizedBox(width: 4),
                    const Icon(Icons.edit, size: 12, color: AppColors.adminTextSecondary),
                  ]),
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.access_time, size: 12, color: AppColors.adminTextSecondary),
                    const SizedBox(width: 4),
                    Flexible(child: Text(matchTime.isEmpty ? '--:--' : (matchDate.isEmpty ? matchTime : '\$matchTime – \$matchDate'), style: const TextStyle(fontSize: 11, color: AppColors.adminTextSecondary), overflow: TextOverflow.ellipsis)),
                  ]),
                  const SizedBox(height: 6),
                  infoChip(stageLabel.isEmpty ? '-' : stageLabel),
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.location_on, size: 12, color: AppColors.adminTextSecondary),
                    const SizedBox(width: 4),
                    Flexible(child: Text(court, style: const TextStyle(fontSize: 11, color: AppColors.adminPrimary, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                  ]),
                ],
              ),
            ),
            Expanded(
              child: Container(
                color: AppColors.adminSurface,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            teamLine(teamA, homeWins, isFinished ? homeScore : null),
                            Container(height: 1, margin: const EdgeInsets.symmetric(vertical: 8), color: AppColors.adminSurfaceElevated),
                            teamLine(teamB, awayWins, isFinished ? awayScore : null),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      decoration: const BoxDecoration(border: Border(left: BorderSide(color: AppColors.adminSurfaceElevated))),
                      child: qrBox,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

""");
  }

  file.writeAsStringSync(text);
}
