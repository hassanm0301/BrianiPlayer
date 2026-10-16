import 'package:flutter/material.dart';

/// A section of a long page that a [SectionJumpList] can jump to.
class JumpSection {
  const JumpSection(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Tracks which section of a long, fully built scroll page is on screen and
/// scrolls to a section on request. Every section must stay mounted (use a
/// Column, or a list with a cache extent covering the whole page) so its key
/// can be measured.
mixin SectionScrollSpy<T extends StatefulWidget> on State<T> {
  final scrollController = ScrollController();
  late final List<GlobalKey> sectionKeys = List.generate(
    sectionCount,
    (_) => GlobalKey(),
  );
  int currentSection = 0;

  int get sectionCount;

  @override
  void initState() {
    super.initState();
    scrollController.addListener(_updateCurrent);
  }

  @override
  void dispose() {
    scrollController.removeListener(_updateCurrent);
    scrollController.dispose();
    super.dispose();
  }

  void _updateCurrent() {
    if (!scrollController.hasClients) return;
    final position = scrollController.position;
    var current = 0;
    if (position.pixels >= position.maxScrollExtent - 4) {
      current = sectionCount - 1;
    } else {
      final viewport = position.context.notificationContext?.findRenderObject();
      for (var i = 0; i < sectionCount; i++) {
        final box = sectionKeys[i].currentContext?.findRenderObject();
        if (box is! RenderBox || viewport == null || !box.attached) continue;
        final top = box.localToGlobal(Offset.zero, ancestor: viewport).dy;
        if (top <= 96) current = i;
      }
    }
    if (current != currentSection && mounted) {
      setState(() => currentSection = current);
    }
  }

  void jumpToSection(int index) {
    final target = sectionKeys[index].currentContext;
    if (target == null) return;
    setState(() => currentSection = index);
    Scrollable.ensureVisible(
      target,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }
}

/// The side list of sections shown next to long pages on wide windows. The
/// section currently on screen is highlighted.
class SectionJumpList extends StatelessWidget {
  const SectionJumpList({
    super.key,
    required this.sections,
    required this.current,
    required this.onSelected,
  });

  final List<JumpSection> sections;
  final int current;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 220,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < sections.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: ListTile(
                dense: true,
                selected: i == current,
                leading: Icon(sections[i].icon),
                title: Text(sections[i].label),
                onTap: () => onSelected(i),
              ),
            ),
        ],
      ),
    ),
  );
}
