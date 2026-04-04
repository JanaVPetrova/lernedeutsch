def pluralize_ru(n, one, few, many)
  mod10  = n.abs % 10
  mod100 = n.abs % 100
  if mod100.between?(11, 19) then many
  elsif mod10 == 1            then one
  elsif mod10.between?(2, 4)  then few
  else                             many
  end
end

MSGS = {
  # ── Main menu ──────────────────────────────────────────────────────────────
  welcome:              ->(name) { "👋 Привет, #{name}! Учим немецкие слова." },
  welcome_back:         ->(name) { "С возвращением, #{name}! Выбери действие:" },

  # ── Keyboard button labels ─────────────────────────────────────────────────
  btn_de_to_ru:         'Немецкий → Перевод',
  btn_ru_to_de:         'Перевод → Немецкий',
  btn_upload:           'Загрузить слова',
  btn_reminder:         'Настроить напоминание',
  btn_snoozed:          'Отложенные слова',
  btn_no_group:         'Без группы',
  btn_all_words:        'Все слова',

  # ── Upload scene ───────────────────────────────────────────────────────────
  upload_pick_group:        'Добавить слова в существующую группу или создать новую?',
  btn_upload_new_group:     '+ Создать новую группу',
  upload_ask_name_ru:       'Как называется эта группа слов? Напиши название по-русски. (например: «Животные», «Глава 3», «Работа»)',
  upload_ask_name_ru_retry: 'Пожалуйста, введи название группы по-русски.',
  upload_ask_name_de:       'Теперь введи название группы по-немецки. (например: «Tiere», «Kapitel 3», «Arbeit»)',
  upload_ask_name_de_retry: 'Пожалуйста, введи название группы по-немецки.',
  upload_ask_words:         ->(ru, de) {
    "Отлично! Теперь пришли файл со словами для группы *#{ru}* / *#{de}*.\n\n" \
    "Формат — TSV-файл или текст, одна пара на строку (разделитель — табуляция):\n" \
    "```\ndas Wort\tслово\nder Hund\tсобака\ngehen\tидти\n```\n" \
    "Артикль (*der/die/das*) не обязателен."
  },
  upload_unreadable:        'Не могу прочитать. Пришли .tsv/.txt файл или вставь слова прямо в чат.',
  upload_no_pairs:          'Не нашла пар слов. Проверь формат (немецкое слово[TAB]перевод) и попробуй снова.',
  upload_done:              ->(count, ru, de) {
    "✅ Добавлено *#{count}* #{pluralize_ru(count, 'слово', 'слова', 'слов')} в группу *#{ru}* / *#{de}*!"
  },
  upload_skipped:           ->(n) { "\n_(#{n} уже существовали и были пропущены)_" },

  # ── Reminder scene ─────────────────────────────────────────────────────────
  reminder_ask_time:    "В какое время напоминать об учёбе?\n\nОтветь в формате *ЧЧ:ММ* (например, _09:00_ или _18:30_).",
  reminder_bad_time:    'Не похоже на правильное время. Используй формат ЧЧ:ММ (например, 09:00).',
  reminder_ask_days:    "Отлично! В какие дни?\n\nНапиши *все*, *будни*, *выходные* или перечисли аббревиатуры через запятую: _mon,wed,fri_.",
  reminder_bad_days:    'Не могу распознать дни. Используй: все, будни, выходные — или аббревиатуры mon–sun.',
  reminder_done:        ->(time, days_str) { "✅ Напоминание установлено на *#{time}*, #{days_str}!" },

  # ── Group picker ───────────────────────────────────────────────────────────
  pick_group_prompt:    'Какую группу слов хочешь практиковать?',

  # ── Learning ───────────────────────────────────────────────────────────────
  learn_prompt_de_to_ru: ->(word) { "Переведи на русский:\n\n*#{word}*" },
  learn_prompt_ru_to_de: ->(word) { "Переведи на немецкий:\n\n*#{word}*" },
  learn_progress:        ->(n) { "#{n} #{pluralize_ru(n, 'слово', 'слова', 'слов')} осталось  |  /stop — выйти" },
  learn_all_done:        ->(n) { "Готово! Ты повторил #{n} #{pluralize_ru(n, 'слово', 'слова', 'слов')} сегодня. Отлично! 🎉" },
  learn_no_words:        'Слов для повторения пока нет. Возвращайся позже! ⏰',
  learn_correct_answer:  ->(answer) { "Правильный ответ: *#{answer}*" },
  learn_session_stats:   ->(rows) {
    header = "📊 *Итоги сессии*\n\n"
    header + rows.map { |r|
      icon = case r[:score]
             when 100    then '🎉'
             when 75..99 then '👍'
             when 50..74 then '⚠️'
             when 1..49  then '❌'
             else             '⏭'
             end
      "#{icon} #{r[:word]} — #{r[:score]}%"
    }.join("\n")
  },
  learn_session_none:    'Ты не успел ответить ни на одно слово.',

  # ── Learning keyboard buttons ──────────────────────────────────────────────
  btn_skip:           'Пропустить',
  btn_snooze:         'Отложить',
  btn_report_mistake: 'Сообщить об ошибке',
  btn_back:           '← Назад',

  # ── Answer feedback ────────────────────────────────────────────────────────
  feedback_perfect:  '🎉 Идеально!',
  feedback_almost:   ->(pct) { "👍 Почти! (#{pct}%)" },
  feedback_partial:  ->(pct) { "⚠️ Частично верно (#{pct}%)" },
  feedback_wrong:    ->(pct) { "❌ Неверно (#{pct}%)" },
  feedback_empty:    '❌ Пропущено',

  # ── Snooze ────────────────────────────────────────────────────────────────
  snoozed_done:         '💤 Слово отложено.',
  btn_unsnooze:         '▶ Вернуть',
  snoozed_list_header:  'Отложенные слова. Нажми на слово, чтобы вернуть его в очередь:',
  snoozed_list_empty:   'Отложенных слов нет.',
  unsnoozed_done:       ->(word) { "✅ *#{word}* возвращено в очередь." },

  # ── Edit word scene ────────────────────────────────────────────────────────
  edit_ask_translation: ->(german, translation) { "Редактируем слово:\n\n🇩🇪 *#{german}*\n🇷🇺 #{translation}\n\nВведи правильный перевод на русский:" },
  edit_ask_german:      ->(current) { "Текущее немецкое слово: *#{current}*\n\nВведи правильное немецкое слово (с артиклем, если нужно):" },
  edit_done:            '✅ Слово обновлено! Продолжаем.',
  edit_invalid_german:  'Не удалось сохранить. Проверь немецкое слово и попробуй ещё раз.',
}.freeze
