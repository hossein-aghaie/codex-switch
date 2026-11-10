#Requires -Version 5.1
[CmdletBinding()]
param([string]$CodexHome = $(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE '.codex' }))
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Security
try {
    if ($env:OS -ne 'Windows_NT') { throw 'Windows 11 is required.' }
    . (Join-Path $PSScriptRoot 'Core.ps1')
    Initialize-Cas $CodexHome ''
} catch {
    $message='Could not start Codex Switch. Close any old switcher window, extract the entire ZIP, and run Start.cmd again.'
    if ($_.Exception.Message -like 'CAS|LOCK|*') { $message='Another switcher is open. Close the old switcher first.' }
    $null=[Windows.MessageBox]::Show($message,'Codex Switch','OK','Error')
    exit 1
}

[xml]$xaml=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
 xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="Codex Switch · Local accounts"
 Width="960" Height="720" MinWidth="760" MinHeight="520" WindowStartupLocation="CenterScreen"
 Background="#0C1221" Foreground="#ECF2FF" FontFamily="Segoe UI" FontSize="14"
 UseLayoutRounding="True" TextOptions.TextFormattingMode="Display">
 <Window.Resources>
  <Style TargetType="Button">
   <Setter Property="Foreground" Value="#ECF2FF"/><Setter Property="Background" Value="#243149"/>
   <Setter Property="BorderBrush" Value="#35445E"/><Setter Property="BorderThickness" Value="1"/>
   <Setter Property="Padding" Value="14,10"/><Setter Property="Cursor" Value="Hand"/>
   <Setter Property="Margin" Value="0,4,0,4"/>
   <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button">
    <Border x:Name="ButtonBorder" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="9" Padding="{TemplateBinding Padding}">
     <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
    </Border><ControlTemplate.Triggers>
     <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="ButtonBorder" Property="Opacity" Value="0.82"/></Trigger>
     <Trigger Property="IsPressed" Value="True"><Setter TargetName="ButtonBorder" Property="Opacity" Value="0.65"/></Trigger>
     <Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="ButtonBorder" Property="BorderBrush" Value="#B3C5FF"/></Trigger>
     <Trigger Property="IsEnabled" Value="False"><Setter TargetName="ButtonBorder" Property="Opacity" Value="0.4"/></Trigger>
    </ControlTemplate.Triggers>
   </ControlTemplate></Setter.Value></Setter>
  </Style>
 </Window.Resources>
 <ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
 <Grid Margin="28">
  <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
  <Grid Grid.Row="0" Margin="0,0,0,20">
   <StackPanel><TextBlock Text="Codex Switch" FontSize="30" FontWeight="SemiBold"/><TextBlock Text="LOCAL ACCOUNTS  /  WINDOWS 11" Foreground="#90A3C4" FontSize="11" Margin="2,5,0,0"/></StackPanel>
   <Border HorizontalAlignment="Right" VerticalAlignment="Center" Background="#192A37" CornerRadius="20" Padding="14,7"><TextBlock Text="●  LOCAL + ENCRYPTED" Foreground="#81D9B3" FontSize="11"/></Border>
  </Grid>
  <Border Grid.Row="1" Background="#162238" BorderBrush="#2A3B59" BorderThickness="1" CornerRadius="12" Padding="18" Margin="0,0,0,20">
   <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
    <StackPanel><TextBlock Text="نشست انتخاب‌شده در فایل محلی" Foreground="#9CADC8" FlowDirection="RightToLeft" HorizontalAlignment="Left"/>
     <TextBlock x:Name="CurrentEmail" Text="—" FontSize="19" FontWeight="SemiBold" Margin="0,6,0,4" TextTrimming="CharacterEllipsis"/>
     <TextBlock x:Name="ModeText" Foreground="#9CADC8" FontSize="12" TextWrapping="Wrap"/>
    </StackPanel>
    <Button x:Name="RefreshButton" Grid.Column="1" Content="تازه‌سازی" VerticalAlignment="Center" Margin="14,0,0,0"/>
   </Grid>
  </Border>
  <StackPanel Grid.Row="2" Margin="0,0,0,14" FlowDirection="RightToLeft">
   <TextBlock Text="حساب‌هایت، در دسترس" FontSize="22" FontWeight="SemiBold"/>
   <TextBlock Text="هر حساب را یک بار اضافه کن؛ بعد با یک دکمه جابه‌جا شو." Foreground="#9CADC8" Margin="0,6,0,0"/>
  </StackPanel>
  <Grid x:Name="AccountActions" Grid.Row="3">
   <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="20"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
   <Border x:Name="Card1" Grid.Column="0" Background="#141F33" BorderBrush="#2C3B55" BorderThickness="1" CornerRadius="16" Padding="20">
    <StackPanel>
     <Grid Margin="0,0,0,18"><TextBlock Text="01" Foreground="#729DFF" FontSize="29" FontWeight="Bold"/><TextBlock x:Name="Badge1" Text="خالی" HorizontalAlignment="Right" VerticalAlignment="Center" Foreground="#9CADC8"/></Grid>
     <TextBlock x:Name="Email1" Text="حساب اول" FontSize="17" FontWeight="SemiBold" TextTrimming="CharacterEllipsis" ToolTip="Account 1"/>
     <TextBlock x:Name="Info1" Text="هنوز حسابی ذخیره نشده" Foreground="#9CADC8" FontSize="12" Margin="0,8,0,18" FlowDirection="RightToLeft" TextWrapping="Wrap" MinHeight="34"/>
     <Button x:Name="Switch1" Content="فعال‌کردن و بازکردن کدکس" Background="#416FE6" BorderBrush="#5682F1" FontWeight="SemiBold"/>
     <Button x:Name="Login1" Content="افزودن / ورود دوباره"/>
     <Button x:Name="Import1" Content="ذخیره نشست محلی در حساب ۱" Background="Transparent" BorderBrush="#2C3B55" Foreground="#B8C9E8"/>
    </StackPanel>
   </Border>
   <Border x:Name="Card2" Grid.Column="2" Background="#141F33" BorderBrush="#2C3B55" BorderThickness="1" CornerRadius="16" Padding="20">
    <StackPanel>
     <Grid Margin="0,0,0,18"><TextBlock Text="02" Foreground="#B19BFF" FontSize="29" FontWeight="Bold"/><TextBlock x:Name="Badge2" Text="خالی" HorizontalAlignment="Right" VerticalAlignment="Center" Foreground="#9CADC8"/></Grid>
     <TextBlock x:Name="Email2" Text="حساب دوم" FontSize="17" FontWeight="SemiBold" TextTrimming="CharacterEllipsis" ToolTip="Account 2"/>
     <TextBlock x:Name="Info2" Text="هنوز حسابی ذخیره نشده" Foreground="#9CADC8" FontSize="12" Margin="0,8,0,18" FlowDirection="RightToLeft" TextWrapping="Wrap" MinHeight="34"/>
     <Button x:Name="Switch2" Content="فعال‌کردن و بازکردن کدکس" Background="#7454C6" BorderBrush="#8E6FE0" FontWeight="SemiBold"/>
     <Button x:Name="Login2" Content="افزودن / ورود دوباره"/>
     <Button x:Name="Import2" Content="ذخیره نشست محلی در حساب ۲" Background="Transparent" BorderBrush="#2C3B55" Foreground="#B8C9E8"/>
    </StackPanel>
   </Border>
  </Grid>
  <Grid Grid.Row="4" Margin="0,18,0,12">
   <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
   <CheckBox x:Name="DeviceCode" Content="ورود با کد دستگاه (جایگزین مرورگر)" VerticalAlignment="Center" Foreground="#B8C9E8" FlowDirection="RightToLeft" HorizontalAlignment="Left"/>
   <Button x:Name="OpenButton" Grid.Column="1" Content="بازکردن کدکس" Margin="8,0,0,0"/>
   <Button x:Name="RestoreButton" Grid.Column="2" Content="بازگردانی قبلی" Margin="8,0,0,0"/>
  </Grid>
  <Border Grid.Row="5" Background="#101A2C" CornerRadius="10" Padding="14">
   <StackPanel FlowDirection="RightToLeft">
    <TextBlock x:Name="StatusText" Text="آماده" Foreground="#81D9B3" TextWrapping="Wrap"/>
    <TextBlock Text="هنگام سوییچ، کدکس دوباره باز می‌شود. کارهای در حال اجرا را اول ذخیره کن. اعتبار نشست را خود کدکس بررسی می‌کند." Foreground="#8496B5" FontSize="11" Margin="0,7,0,0" TextWrapping="Wrap"/>
   </StackPanel>
  </Border>
 </Grid></ScrollViewer>
</Window>
'@

try {
    $window=[Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($xaml))
    $workArea=[Windows.SystemParameters]::WorkArea
    $window.MinWidth=[Math]::Min(760,[Math]::Max(500,$workArea.Width-24))
    $window.MinHeight=[Math]::Min(520,[Math]::Max(350,$workArea.Height-24))
    $window.Width=[Math]::Min(960,$workArea.Width-24)
    $window.Height=[Math]::Min(720,$workArea.Height-24)
    $script:Ui=@{}
    foreach ($name in @('CurrentEmail','ModeText','RefreshButton','AccountActions','Card1','Card2','Badge1','Badge2','Email1','Email2','Info1','Info2','Switch1','Switch2','Login1','Login2','Import1','Import2','DeviceCode','OpenButton','RestoreButton','StatusText')) { $script:Ui[$name]=$window.FindName($name) }
    $script:Busy=$false
    $script:Installation=$null
    $script:CasPump={
        $frame=[Windows.Threading.DispatcherFrame]::new()
        $null=$window.Dispatcher.BeginInvoke([Windows.Threading.DispatcherPriority]::Background, [Windows.Threading.DispatcherOperationCallback]{ param($f) $f.Continue=$false; return $null }, $frame)
        [Windows.Threading.Dispatcher]::PushFrame($frame)
    }
    $script:CasReport={
        param($Message)
        $display=switch ($Message) {
            'Closing Codex...' { 'در حال بستن کدکس و حفظ نشست فعلی…' }
            'Opening Codex with the selected account...' { 'در حال بازکردن کدکس با حساب انتخاب‌شده…' }
            default { 'ورود را در صفحه رسمی مرورگر یا پنجره ورود کامل کن؛ برای لغو، پنجره ورود را ببند.' }
        }
        $script:Ui.StatusText.Text=$display
        & $script:CasPump
    }

    function Get-UiInstallation {
        # Re-discover every time so app updates cannot leave stale package paths.
        return (Find-CasInstallation)
    }
    function Update-CasUi {
        $state=Get-CasStatus
        $script:Ui.CurrentEmail.Text='نشست محلی پیدا نشد'
        if ($null -ne $state.Current) { $script:Ui.CurrentEmail.Text=$state.Current.Email }
        $script:Ui.ModeText.Text='ذخیره‌سازی فایل هنگام اولین سوییچ، با پشتیبان‌گیری آماده می‌شود.'
        if ($state.FileMode) { $script:Ui.ModeText.Text='حالت فایل آماده است · نام بالا از فایل محلی خوانده شده، نه از سرور.' }
        foreach ($item in $state.Slots) {
            $n=[string]$item.Slot
            $script:Ui['Switch'+$n].IsEnabled=($item.State -eq 'saved')
            $script:Ui['Import'+$n].IsEnabled=($null -ne $state.Current -and $item.State -ne 'unreadable')
            $script:Ui['Login'+$n].IsEnabled=($item.State -ne 'unreadable')
            $script:Ui['Card'+$n].BorderBrush='#2C3B55'
            if ($item.State -eq 'saved') {
                $script:Ui['Email'+$n].Text=$item.Email
                $script:Ui['Email'+$n].ToolTip=$item.Email
                $script:Ui['Badge'+$n].Text='ذخیره‌شده'
                $script:Ui['Info'+$n].Text='رمزگذاری ویندوز · به‌روزرسانی: '+$item.Updated
                if ($item.IsCurrent) {
                    $script:Ui['Badge'+$n].Text='● انتخاب محلی'
                    $script:Ui['Card'+$n].BorderBrush='#66C99F'
                }
            } elseif ($item.State -eq 'empty') {
                $script:Ui['Email'+$n].Text='حساب '+$n
                $script:Ui['Badge'+$n].Text='خالی'
                $script:Ui['Info'+$n].Text='یک بار اضافه کن؛ نشست روی همین ویندوز ذخیره می‌شود.'
            } else {
                $script:Ui['Email'+$n].Text='فایل ذخیره‌شده قابل خواندن نیست'
                $script:Ui['Badge'+$n].Text='نیاز به بررسی'
                $script:Ui['Info'+$n].Text='ممکن است متعلق به کاربر یا ویندوز دیگری باشد؛ بازنویسی نمی‌شود.'
            }
        }
        if ($state.Pending) { $script:Ui.StatusText.Text='سوییچ قبلی کامل نشده؛ ابتدا «بازگردانی قبلی» را بزن.' }
    }

    function Show-CasError($Record) {
        $text=[string]$Record.Exception.Message
        if ($text -like 'CAS|*') {
            $parts=$text.Split('|',3)
            $summary=switch ($parts[1]) {
                'LOCK' { 'نسخه قبلی یا پنجره دیگری از سوییچر باز است؛ اول آن را ببند.' }
                'NOAUTH' { 'فایل نشست محلی پیدا نشد. از دکمه «افزودن / ورود دوباره» استفاده کن.' }
                'FORMAT' { 'نشست خوانده‌شده پشتیبانی نمی‌شود؛ با دکمه افزودن، ورود رسمی انجام بده.' }
                'DIFFERENT' { 'این جایگاه متعلق به حساب دیگری است. جایگاه خالی را انتخاب کن یا با همان حساب قبلی وارد شو.' }
                'DUPLICATE' { 'این حساب قبلاً در جایگاه دیگر ذخیره شده؛ هنگام ورود، حساب دوم مرورگر را انتخاب کن.' }
                'INSTALL' { 'نصب برنامه رسمی کدکس به‌طور دقیق پیدا نشد. برنامه را از منوی Start باز و نصبش را بررسی کن.' }
                'CLI' { 'ابزار رسمی ورود در نصب کدکس پیدا نشد. برنامه رسمی را به‌روز کن؛ چیزی از منبع دیگر نصب نمی‌شود.' }
                'CONFIG' { 'ساختار تنظیمات نیاز به بررسی دارد؛ ابزار آن را حدسی تغییر نداد.' }
                'LOGIN' { 'ورود رسمی کامل نشد یا لغو شد. حساب‌های ذخیره‌شده تغییر نکردند.' }
                'PENDING' { 'سوییچ قبلی کامل نشده؛ ابتدا دکمه «بازگردانی قبلی» را بزن.' }
                'RECOVERY' { 'هنوز پشتیبان سوییچ ساخته نشده است.' }
                'ROLLBACK' { 'سوییچ کامل نشد و بازگردانی هم نیاز به رسیدگی دارد. کدکس را ببند و «بازگردانی قبلی» را بزن؛ پشتیبان رمزگذاری‌شده حفظ شده است.' }
                'UNSAVED' { 'نشست فعلی با هیچ‌کدام از دو حساب ذخیره‌شده مطابقت ندارد؛ ابتدا وضعیت حساب‌ها را بررسی کن.' }
                'EXTERNALCLI' { 'یک نسخه دیگر از Codex CLI باز است؛ ترمینال همان نسخه را ببند و دوباره امتحان کن.' }
                'UNKNOWNPROCESS' { 'مسیر یکی از پردازش‌ها قابل بررسی نیست؛ آن برنامه را دستی ببند. ابزار صرفاً بر اساس نام، پردازشی را نمی‌بندد.' }
                'LAUNCH' { 'کدکس پس از سوییچ باز نماند؛ وضعیت محلی قبلی بازگردانده شد.' }
                'VERIFY' { 'هویت محلی بعد از سوییچ با حساب انتخابی مطابقت نداشت؛ وضعیت قبلی بازگردانده شد.' }
                default { 'عملیات کامل نشد؛ جزئیات زیر را بررسی کن.' }
            }
            $text=$summary+"`n`n"+$parts[2]+"`n"+'کد: '+$parts[1]
        } else {
            $text='عملیات کامل نشد. جزئیات حساس نمایش داده نمی‌شود. نوع خطا: '+$Record.Exception.GetType().Name+' · کد: '+$Record.Exception.HResult
        }
        $script:Ui.StatusText.Text=$text
        $null=[Windows.MessageBox]::Show($window,$text,'Codex Switch','OK','Warning')
    }

    function Invoke-CasUiAction([scriptblock]$Action, [switch]$AllowForce) {
        if ($script:Busy) { return }
        $script:Busy=$true
        $script:Ui.AccountActions.IsEnabled=$false
        foreach ($key in @('RefreshButton','OpenButton','RestoreButton','DeviceCode')) { $script:Ui[$key].IsEnabled=$false }
        try {
            try { & $Action $false }
            catch {
                if ($AllowForce -and $_.Exception.Message -like 'CAS|RUNNING|*') {
                    $names=$_.Exception.Message.Split('|',3)[2]
                    $answer=[Windows.MessageBox]::Show($window,('این پردازش‌های کدکس هنوز بسته نشده‌اند:'+"`n"+$names+"`n`n"+'کار ذخیره‌نشده ممکن است از دست برود. فقط همین پردازش‌های تأییدشده به اجبار بسته شوند؟'),'بستن کدکس','YesNo','Warning')
                    if ($answer -eq 'Yes') { & $Action $true }
                    else { $script:Ui.StatusText.Text='لغو شد؛ حساب تغییر نکرد.' }
                } else { throw }
            }
        } catch { Show-CasError $_ }
        finally {
            $script:Busy=$false
            $script:Ui.AccountActions.IsEnabled=$true
            foreach ($key in @('RefreshButton','OpenButton','RestoreButton','DeviceCode')) { $script:Ui[$key].IsEnabled=$true }
            try { Update-CasUi } catch { $script:Ui.StatusText.Text='خواندن وضعیت کامل نشد؛ برنامه را دوباره باز کن.' }
        }
    }

    function Invoke-UiSwitch([int]$Slot) {
        $answer=[Windows.MessageBox]::Show($window,'کارهای باز کدکس را ذخیره کرده‌ای؟ ابزار کدکس را می‌بندد، حساب را عوض می‌کند و دوباره بازش می‌کند. در نسخه‌های یکپارچه، پنجره ChatGPT همین نصب هم بسته می‌شود.','جابه‌جایی حساب','YesNo','Question')
        if ($answer -ne 'Yes') { return }
        Invoke-CasUiAction -AllowForce -Action {
            param($Force)
            $installation=Get-UiInstallation
            $account=Invoke-CasSwitch $Slot $installation -Force:$Force
            $script:Ui.StatusText.Text='حساب انتخاب شد: '+$account.Email+' · حساب نمایش‌داده‌شده داخل کدکس را هم بررسی کن.'
        }
    }
    function Invoke-UiLogin([int]$Slot) {
        $answer=[Windows.MessageBox]::Show($window,'پنجره ورود رسمی باز می‌شود. برای حساب دوم، همان حساب دوم را در مرورگر انتخاب کن. رمز و کد تأیید را فقط در صفحه رسمی وارد کن. نشست فعلی کدکس با این مرحله عوض نمی‌شود.','افزودن حساب','OKCancel','Information')
        if ($answer -ne 'OK') { return }
        Invoke-CasUiAction {
            param($Force)
            $account=Add-CasLogin $Slot (Get-UiInstallation) -DeviceCode:([bool]$script:Ui.DeviceCode.IsChecked)
            $script:Ui.StatusText.Text='حساب ذخیره شد: '+$account.Email+' · حالا دکمه فعال‌کردن را بزن.'
        }
    }
    function Invoke-UiImport([int]$Slot) {
        Invoke-CasUiAction {
            param($Force)
            $bytes=Read-CasLive
            $account=Get-CasAccount $bytes
            $answer=[Windows.MessageBox]::Show($window,('این نشست محلی در حساب '+$Slot+' ذخیره شود؟'+"`n"+$account.Email+"`n`n"+'این مرحله فایل محلی را می‌خواند؛ نشست سرور را بررسی نمی‌کند.'),'ذخیره نشست موجود','YesNo','Question')
            if ($answer -eq 'Yes') {
                $null=Save-CasAccount $Slot $bytes
                $script:Ui.StatusText.Text='ذخیره شد: '+$account.Email
            }
        }
    }

    $script:Ui.Switch1.Add_Click({ Invoke-UiSwitch 1 })
    $script:Ui.Switch2.Add_Click({ Invoke-UiSwitch 2 })
    $script:Ui.Login1.Add_Click({ Invoke-UiLogin 1 })
    $script:Ui.Login2.Add_Click({ Invoke-UiLogin 2 })
    $script:Ui.Import1.Add_Click({ Invoke-UiImport 1 })
    $script:Ui.Import2.Add_Click({ Invoke-UiImport 2 })
    $script:Ui.RefreshButton.Add_Click({ Invoke-CasUiAction { param($Force) Update-CasUi; $script:Ui.StatusText.Text='وضعیت تازه شد.' } })
    $script:Ui.OpenButton.Add_Click({ Invoke-CasUiAction { param($Force) Start-CasDesktop (Get-UiInstallation); $script:Ui.StatusText.Text='درخواست بازشدن کدکس ارسال شد.' } })
    $script:Ui.RestoreButton.Add_Click({
        $answer=[Windows.MessageBox]::Show($window,'کدکس بسته می‌شود و فایل ورود و تنظیمات به وضعیت پیش از آخرین سوییچ برمی‌گردند. ادامه می‌دهی؟','بازگردانی','YesNo','Question')
        if ($answer -eq 'Yes') {
            Invoke-CasUiAction -AllowForce -Action {
                param($Force)
                $installation=Get-UiInstallation
                Stop-CasDesktop $installation -Force:$Force
                Restore-CasTransaction
                Start-CasDesktop $installation
                $script:Ui.StatusText.Text='وضعیت محلی قبلی بازگردانده شد.'
            }
        }
    })
    $window.Add_Closing({ param($sender,$eventArgs)
        if ($script:Busy) { $eventArgs.Cancel=$true; $script:Ui.StatusText.Text='عملیات در جریان است؛ برای لغو ورود، پنجره ورود رسمی را ببند.' }
    })
    $timer=[Windows.Threading.DispatcherTimer]::new()
    $timer.Interval=[TimeSpan]::FromSeconds(4)
    $timer.Add_Tick({ if (-not $script:Busy) { try { Update-CasUi } catch { } } })
    Update-CasUi
    $timer.Start()
    $null=$window.ShowDialog()
    $timer.Stop()
} catch {
    $null=[Windows.MessageBox]::Show(('The window could not run. Error type: '+$_.Exception.GetType().Name),'Codex Switch','OK','Error')
} finally { Close-Cas }
