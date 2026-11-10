# Codex Switch

یک ابزار مستقل و غیررسمی برای جابه‌جایی بین دو حساب Codex در ویندوز ۱۱، با رابط گرافیکی فارسی.

**[راهنمای کامل فارسی](README-fa.md)** · [English overview](#english-overview)

بعد از اینکه هر حساب را یک بار از مسیر رسمی وارد کردی، می‌توانی نشست ذخیره‌شدهٔ آن را از کارت خودش فعال کنی. برنامه مرورگر را برای هر سوییچ عادی باز نمی‌کند؛ اگر نشست منقضی یا لغو شود، ورود رسمی دوباره لازم است. ابزار رمز عبور یا کوکی مرورگر را نمی‌خواند.

## شروع سریع

1. نسخه رسمی Codex برای Windows 11 را نصب کن و کل این ریپو را در یک پوشه دریافت یا دانلود و Extract کن.
2. روی `Start.cmd` دوبار کلیک کن. Python، Node.js و دسترسی Administrator لازم نیست.
3. اگر نشست فعلی درست نمایش داده می‌شود، آن را در کارت حساب ۱ ذخیره کن. برای حساب ۲ روی «افزودن / ورود دوباره» بزن و ورود رسمی حساب دوم را کامل کن.
4. برای جابه‌جایی، کارهای باز را ذخیره کن و «فعال‌کردن و بازکردن کدکس» را روی کارت حساب موردنظر بزن.

«بازگردانی قبلی» برای بازیابی فایل ورود و تنظیمات به وضعیت پیش از **آخرین سوییچ** است؛ جای دکمهٔ جابه‌جایی عادی را نمی‌گیرد. اگر پیام «سوییچ قبلی کامل نشده» ظاهر شد، بخش بازیابی در [راهنمای فارسی](README-fa.md) را بخوان. تیک «ورود با کد دستگاه» فقط روش **افزودن / ورود دوباره** را تغییر می‌دهد.

## ایمنی و وضعیت تست

نسخه‌های ذخیره‌شدهٔ نشست با Windows DPAPI برای کاربر فعلی رمزگذاری می‌شوند؛ فایل فعال `CODEX_HOME/auth.json` همچنان حاوی توکن است و باید مثل رمز عبور محافظت شود. فایل‌های نشست، آرشیو خصوصی و تصویر واقعی حساب‌ها را منتشر نکن. جزئیات در [راهنمای امنیت](SECURITY.md) آمده است.

آزمون‌های آفلاین با حساب ساختگی روی ویندوز پاس شده‌اند و سازنده جابه‌جایی واقعی بین دو حساب را روی سیستم خود گزارش کرده است. این تجربه تضمین سازگاری همهٔ نصب‌ها یا اعتبار نشست در سرور نیست. تست خودکار ریپو فقط منطق محلی را اجرا می‌کند.

## English overview

Codex Switch is an unofficial, local PowerShell/WPF utility for switching between two saved Codex sign-ins on Windows 11. Sign in to each account once through the official Codex flow; later switches reuse the local session while it remains valid. The app closes and reopens the detected desktop installation during a switch.

- Run `Start.cmd` after extracting the repository. No Python, Node.js, or administrator access is needed.
- Run `Test.cmd` for offline tests with synthetic accounts, or `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Test-Core.ps1` in a terminal.
- Saved account snapshots use Windows DPAPI for the current user. The active Codex `auth.json` is still sensitive plaintext.
- **Restore previous** restores the auth file and config from before the last switch. It is a recovery action, not a third account slot or ordinary toggle.
- Device-code sign-in is an alternative for adding or reauthenticating an account; it is not needed for ordinary switching.

Read the [full Persian guide](README-fa.md), [security notes](SECURITY.md), and [source notes](SOURCES.md). This project is not affiliated with or endorsed by OpenAI.
