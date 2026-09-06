/// Реквизиты и контакты компании для раздела «О приложении».
///
/// Пустая строка означает «ещё не известно» — экран покажет «Уточняется»
/// вместо строки. Выдумывать ИНН и ОГРН нельзя: это сведения, которые
/// читатель воспримет как достоверные.
///
/// Источник данных — бекенд (`GET /api/v1/company-details`, редактируется
/// из админки); эти значения — только оффлайн-заглушка на случай, если
/// приложение ни разу не смогло достучаться до сервера.
class CompanyDetails {
  const CompanyDetails({
    this.legalName = '',
    this.brandName = 'КрымТрип',
    this.inn = '',
    this.ogrn = '',
    this.address = '',
    this.email = '',
    this.phone = '',
    this.telegram = '',
    this.workingHours = 'Ежедневно с 10:00 до 20:00 (МСК)',
  });

  factory CompanyDetails.fromJson(Map<String, dynamic> json) {
    return CompanyDetails(
      legalName: json['legal_name'] as String? ?? '',
      brandName: json['brand_name'] as String? ?? 'КрымТрип',
      inn: json['inn'] as String? ?? '',
      ogrn: json['ogrn'] as String? ?? '',
      address: json['address'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      telegram: json['telegram'] as String? ?? '',
      workingHours: json['working_hours'] as String? ?? '',
    );
  }

  final String legalName;
  final String brandName;
  final String inn;
  final String ogrn;
  final String address;
  final String email;
  final String phone;
  final String telegram;
  final String workingHours;

  Map<String, dynamic> toJson() => {
    'legal_name': legalName,
    'brand_name': brandName,
    'inn': inn,
    'ogrn': ogrn,
    'address': address,
    'email': email,
    'phone': phone,
    'telegram': telegram,
    'working_hours': workingHours,
  };
}
