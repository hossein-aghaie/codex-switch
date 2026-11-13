# Codex Switch

<div dir="rtl" lang="fa">

یک ابزار مستقل و غیررسمی برای جابه‌جایی بین چند حساب Codex در ویندوز ۱۱، با رابط گرافیکی فارسی.

**[راهنمای کامل فارسی](README-fa.md)** · [English overview](#english-overview)

**[دریافت آخرین نسخهٔ آماده](https://github.com/hossein-aghaie/codex-switch/releases/latest)**

بعد از اینکه هر حساب را یک بار از مسیر رسمی وارد کردی، می‌توانی نشست ذخیره‌شدهٔ آن را از فهرست فعال کنی. برنامه مرورگر را برای هر سوییچ عادی باز نمی‌کند؛ اگر نشست منقضی یا لغو شود، ورود رسمی دوباره لازم است. ابزار رمز عبور یا کوکی مرورگر را نمی‌خواند.

## شروع سریع

1. نسخه رسمی Codex برای Windows 11 را نصب کن و کل این ریپو را در یک پوشه دریافت یا دانلود و Extract کن.
2. روی `Start.cmd` دوبار کلیک کن. Python، Node.js و دسترسی Administrator لازم نیست.
3. اگر نشست فعلی درست نمایش داده می‌شود، «ذخیره نشست فعلی» را بزن. برای حساب‌های دیگر، «+ افزودن حساب» را بزن و ورود رسمی را کامل کن.
4. برای جابه‌جایی، کارهای باز را ذخیره کن و دکمهٔ آبی «سوییچ به این حساب» را در ردیف حساب موردنظر بزن؛ برنامه Codex را می‌بندد و دوباره باز می‌کند. «ورود - در صورت منقضی شدن» فقط برای نشست منقضی یا خراب همان حساب است. حساب‌های خارج از صفحه با دکمه‌های «قبلی» و «بعدی» دیده می‌شوند.

اگر سوییچی نیمه‌تمام بماند، برنامه دو راه نشان می‌دهد: «ادامه با حساب فعلی» پس از بررسی حساب در خود Codex، بدون بستن آن؛ یا «بازگشت به قبل» که Codex را می‌بندد و فایل‌های قبلی را بازیابی می‌کند. توضیح در [راهنمای فارسی](README-fa.md) آمده است. وضعیت هر چند ثانیه خودکار به‌روز می‌شود. تیک «ورود با کد دستگاه» فقط روش **افزودن حساب / ورود دوباره** را تغییر می‌دهد. دو پروفایل ذخیره‌شدهٔ نسخهٔ قبلی بدون جابه‌جایی فایل‌ها خوانده می‌شوند.

## ایمنی و وضعیت تست

نسخه‌های ذخیره‌شدهٔ نشست با Windows DPAPI برای کاربر فعلی رمزگذاری می‌شوند؛ فایل فعال `CODEX_HOME/auth.json` همچنان حاوی توکن است و باید مثل رمز عبور محافظت شود. فایل‌های نشست، آرشیو خصوصی و تصویر واقعی حساب‌ها را منتشر نکن. جزئیات در [راهنمای امنیت](SECURITY.md) آمده است.

آزمون‌های آفلاین چندحسابی با حساب ساختگی روی ویندوز پاس شده‌اند. جابه‌جایی واقعی بین دو حساب در نسخهٔ قبلی گزارش شده است؛ نسخهٔ چندحسابی هنوز با حساب واقعی آزمایش نشده. تست خودکار ریپو فقط منطق محلی را اجرا می‌کند.

</div>

## English overview

Codex Switch is an unofficial, local PowerShell/WPF utility for switching among multiple saved Codex sign-ins on Windows 11. Sign in to each account once through the official Codex flow; later switches reuse the local session while it remains valid. The app closes and reopens the detected desktop installation during a switch. Existing account 1 and 2 files remain in place.

- Run `Start.cmd` after extracting the repository. No Python, Node.js, or administrator access is needed.
- Run `Test.cmd` for offline tests with synthetic accounts, or `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Test-Core.ps1` in a terminal.
- Saved account snapshots use Windows DPAPI for the current user. The active Codex `auth.json` is still sensitive plaintext.
- An interrupted switch offers **Keep current account** without closing Codex when the saved local identity matches, or **Restore previous state**, which closes Codex and restores the previous auth and config. Confirm the account inside Codex before keeping it. Completed switches cannot be undone from the UI.
- Device-code sign-in is an alternative for adding or reauthenticating an account; it is not needed for ordinary switching.
- In each row, the blue **Switch to this account** action is for normal use. **Sign in again (if needed)** renews a broken or expired sign-in for that same account without switching the active account.

Read the [full Persian guide](README-fa.md), [security notes](SECURITY.md), and [source notes](SOURCES.md). This project is not affiliated with or endorsed by OpenAI.
