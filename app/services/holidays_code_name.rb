class HolidaysCodeName
  COUNTRIES_WITH_CODES = %w(ch)
  CODES =
    {
      'Karfreitag' => 'good_friday',
      'Ostermontag' => 'easter_monday',
      'Auffahrt' => 'ascension_day',
      'Pfingstmontag' => 'whit_monday',
      'Fronleichnam' => 'corpus_christi',
      'Lundi du Jeûne fédéral' => 'federal_prayday',
      'Jeûne genevois' => 'geneva_prayday',
      'Neujahrstag' => 'new_years_day',
      'Berchtoldstag' => 'saint_berchtold',
      'Dreikönigstag' => 'epiphany',
      'Instauration de la République' => 'instauration_republic_neuchatel',
      'Josephstag' => 'saint_joseph',
      'Näfelser Fahrt' => 'naefelser_fahrt',
      'Tag der Arbeit' => 'labour_day',
      'Commémoration du plébiscite jurassien' => 'jura_independance_day',
      'San Pietro e Paolo' => 'sts_peter_and_paul',
      'Bundesfeiertag' => 'swiss_national_day',
      'Mariä Himmelfahrt' => 'assumption_day',
      'Mauritiustag' => 'saint_maurice',
      'Bruderklausenfest' => 'st_niklaus_von_flue',
      'Allerheiligen' => 'all_saints_day',
      'Maria Empfängnis' => 'immaculate_conception',
      'Weihnachten' => 'christmas',
      'Stefanstag' => 'st_stephens_day',
      'Restauration de la République' => 'restoration_republic_geneva'
    }

  def self.get_name_code(holiday_name)
    CODES[holiday_name]
  end
end
