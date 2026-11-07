import 'package:flutter/widgets.dart';

import '../../../app/app_services.dart';
import '../../../design/components/db_text_field.dart';
import '../../../design/components/island_button.dart';
import '../../../design/theme/island_theme.dart';
import '../../../design/tokens/db_colors.dart';
import '../../../design/tokens/db_dimens.dart';
import '../../../design/tokens/db_icons.dart';
import '../../../design/tokens/db_typography.dart';
import '../../../modules/calendar/calendar_entry.dart';
import 'page_scaffold.dart';

/// Untimed calendar notes for today, using the existing calendar store.
class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final TextEditingController _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _add(AppServices services) {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    services.calendar.add(day: services.clock.now, text: text);
    _text.clear();
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.read(context);
    final IslandPalette palette = IslandTheme.of(context).palette;
    return AnimatedBuilder(
      animation: Listenable.merge([services.calendar, services.clock]),
      builder: (context, _) {
        final List<CalendarEntry> entries = services.calendar
            .forDay(services.clock.now)
            .where((entry) => !entry.hasTime)
            .toList();
        return PageScaffold(
          title: 'Notes',
          child: Column(
            children: [
              Expanded(
                child: entries.isEmpty
                    ? const PageEmptyState(
                        message: 'No notes for today',
                        hint: 'Notes are saved with today’s calendar.',
                      )
                    : ListView.builder(
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          return Row(
                            children: [
                              Expanded(
                                child: Text(entry.text,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: DbType.body.copyWith(
                                        color: palette.textPrimary)),
                              ),
                              IslandButton(
                                icon: DbIcons.delete,
                                tooltip: 'Delete note',
                                onPressed: () => services.calendar.remove(entry.id),
                              ),
                            ],
                          );
                        },
                      ),
              ),
              const SizedBox(height: DbSpace.sm),
              Row(
                children: [
                  Expanded(
                    child: DbTextField(
                      controller: _text,
                      placeholder: 'Add a note for today',
                      onSubmitted: (_) => _add(services),
                    ),
                  ),
                  const SizedBox(width: DbSpace.sm),
                  IslandButton(
                    icon: DbIcons.add,
                    tooltip: 'Add note',
                    onPressed: () => _add(services),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
