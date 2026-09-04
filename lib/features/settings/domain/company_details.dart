/// Реквизиты и контакты компании для раздела «О приложении».
///
/// Пустая строка означает «ещё не известно» — экран покажет «Уточняется»
/// вместо строки. Выдумывать ИНН и ОГРН нельзя: это сведения, которые
/// читатель воспримет как достоверные.
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

  final String legalName;
  final String brandName;
  final String inn;
  final String ogrn;
  final String address;
  final String email;
  final String phone;
  final String telegram;
  final String workingHours;
}

const companyDetails = CompanyDetails();
