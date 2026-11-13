#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$CodexHome = $(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE '.codex' }),
    [string]$VaultPath = '',
    [string]$PreviewImage = '',
    [int]$PreviewPage = 0,
    [int]$PreviewWidth = 0,
    [int]$PreviewHeight = 0
)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Security
try {
    if ($env:OS -ne 'Windows_NT') { throw 'Windows 11 is required.' }
    . (Join-Path $PSScriptRoot 'Core.ps1')
    Initialize-Cas $CodexHome $VaultPath
} catch {
    $message='Could not start Codex Switch. Close any old switcher window, extract the entire ZIP, and run Start.cmd again.'
    if ($_.Exception.Message -like 'CAS|LOCK|*') { $message='Another switcher is open. Close the old switcher first.' }
    $null=[Windows.MessageBox]::Show($message,'Codex Switch','OK','Error')
    exit 1
}

[xml]$xaml=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
 xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="Codex Switch · حساب‌های محلی"
 Width="900" Height="630" MinWidth="680" MinHeight="540" WindowStartupLocation="CenterScreen"
 Background="#0C1221" Foreground="#ECF2FF" FontFamily="Segoe UI" FontSize="14"
 UseLayoutRounding="True" TextOptions.TextFormattingMode="Display">
 <Window.Resources>
  <Style TargetType="Button">
   <Setter Property="Foreground" Value="#ECF2FF"/><Setter Property="Background" Value="#243149"/>
   <Setter Property="BorderBrush" Value="#35445E"/><Setter Property="BorderThickness" Value="1"/>
   <Setter Property="Padding" Value="12,8"/><Setter Property="Cursor" Value="Hand"/>
   <Setter Property="MinHeight" Value="38"/>
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
 <Grid Margin="20">
  <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
  <Grid Grid.Row="0" Margin="0,0,0,12">
   <StackPanel Orientation="Horizontal"><TextBlock Text="Codex Switch" FontSize="23" FontWeight="SemiBold"/><TextBlock Text="  ·  حساب‌های محلی" Foreground="#90A3C4" FontSize="14" VerticalAlignment="Bottom"/></StackPanel>
   <TextBlock Text="●  رمزگذاری‌شده در ویندوز" HorizontalAlignment="Right" VerticalAlignment="Center" Foreground="#81D9B3" FontSize="11"/>
  </Grid>
  <Border Grid.Row="1" Background="#162238" BorderBrush="#2A3B59" BorderThickness="1" CornerRadius="12" Padding="12" Margin="0,0,0,12">
   <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
    <StackPanel><TextBlock Text="حساب فعال در فایل محلی" Foreground="#9CADC8" FlowDirection="RightToLeft" HorizontalAlignment="Left" FontSize="11"/>
     <TextBlock x:Name="CurrentEmail" Text="—" FontSize="16" FontWeight="SemiBold" Margin="0,3,0,2" TextTrimming="CharacterEllipsis"/>
     <TextBlock x:Name="ModeText" Foreground="#9CADC8" FontSize="11" TextTrimming="CharacterEllipsis"/>
    </StackPanel>
    <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
     <Button x:Name="OpenButton" Content="بازکردن کدکس" MinWidth="112" Margin="8,0,0,0"/>
    </StackPanel>
   </Grid>
  </Border>
  <Grid Grid.Row="2" Margin="0,0,0,10">
   <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
   <StackPanel><TextBlock Text="حساب‌ها" FontSize="18" FontWeight="SemiBold"/>
    <CheckBox x:Name="DeviceCode" Content="ورود با کد دستگاه" Foreground="#B8C9E8" FlowDirection="RightToLeft" HorizontalAlignment="Left" FontSize="11" Margin="0,4,0,0"/>
   </StackPanel>
   <Button x:Name="SaveCurrentButton" Grid.Column="1" Content="ذخیره نشست فعلی" MinWidth="125" VerticalAlignment="Center" Margin="8,0,0,0"/>
   <Button x:Name="AddButton" Grid.Column="2" Content="+ افزودن حساب" Background="#416FE6" BorderBrush="#5682F1" MinWidth="116" VerticalAlignment="Center" Margin="8,0,0,0"/>
  </Grid>
  <StackPanel x:Name="AccountList" Grid.Row="3" VerticalAlignment="Top"/>
  <Grid Grid.Row="4" Margin="0,4,0,10">
   <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
   <Button x:Name="PrevButton" Content="قبلی" MinWidth="70"/>
   <TextBlock x:Name="PageText" Grid.Column="1" VerticalAlignment="Center" Margin="14,0" Foreground="#9CADC8"/>
   <Button x:Name="NextButton" Grid.Column="2" Content="بعدی" MinWidth="70"/>
   <TextBlock x:Name="CountText" Grid.Column="3" HorizontalAlignment="Right" VerticalAlignment="Center" Foreground="#9CADC8" FontSize="11"/>
  </Grid>
  <Border Grid.Row="5" Background="#101A2C" CornerRadius="10" Padding="10">
   <StackPanel FlowDirection="RightToLeft">
    <TextBlock x:Name="StatusText" Text="آماده" Foreground="#81D9B3" TextWrapping="Wrap"/>
    <TextBlock x:Name="StatusHelp" Text="پیش از جابه‌جایی، کارهای باز را ذخیره کن. وضعیت حساب‌ها هر چند ثانیه خودکار بررسی می‌شود." Foreground="#9CADC8" FontSize="11" Margin="0,4,0,0" TextWrapping="Wrap"/>
    <StackPanel x:Name="RecoveryActions" Orientation="Horizontal" HorizontalAlignment="Left" Visibility="Collapsed" Margin="0,7,0,0">
     <Button x:Name="KeepCurrentButton" Content="ادامه با حساب فعلی" Background="#416FE6" BorderBrush="#5682F1" MinWidth="150" Margin="0,0,8,0"/>
     <Button x:Name="RestoreButton" Content="بازگشت به قبل" FlowDirection="RightToLeft" MinWidth="150" ToolTip="کارهایت را ذخیره کن؛ Codex بسته می‌شود، وضعیت قبل بازیابی می‌شود و دوباره باز می‌شود."/>
    </StackPanel>
   </StackPanel>
  </Border>
 </Grid>
</Window>
'@

try {
    $window=[Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($xaml))
    $workArea=[Windows.SystemParameters]::WorkArea
    $window.MinWidth=[Math]::Min(680,[Math]::Max(500,$workArea.Width-24))
    $window.MinHeight=[Math]::Min(500,[Math]::Max(450,$workArea.Height-24))
    $window.Width=[Math]::Min(900,$workArea.Width-24)
    $window.Height=[Math]::Min(630,$workArea.Height-24)
    if ($PreviewImage) {
        if ($PreviewWidth -ge $window.MinWidth) { $window.Width=$PreviewWidth }
        if ($PreviewHeight -ge $window.MinHeight) { $window.Height=$PreviewHeight }
    }
    $script:Ui=@{}
    foreach ($name in @('CurrentEmail','ModeText','AccountList','AddButton','SaveCurrentButton','PrevButton','NextButton','PageText','CountText','DeviceCode','OpenButton','RecoveryActions','KeepCurrentButton','RestoreButton','StatusText','StatusHelp')) { $script:Ui[$name]=$window.FindName($name) }
    $script:Busy=$false
    $script:Installation=$null
    $script:Page=if ($PreviewImage) { [Math]::Max(0,$PreviewPage) } else { 0 }
    $script:PageSize=if ($window.Height -lt 630) { 2 } else { 3 }
    $script:ListKey=''
    $script:AutoSized=$false
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
    function Render-CasAccounts($Items, [bool]$Pending) {
        $pages=[Math]::Max(1,[int][Math]::Ceiling($Items.Count / $script:PageSize))
        $script:Page=[Math]::Max(0,[Math]::Min($script:Page,$pages-1))
        $script:Ui.PageText.Text=('{0} / {1}' -f ($script:Page+1),$pages)
        $script:Ui.PrevButton.IsEnabled=($script:Page -gt 0)
        $script:Ui.NextButton.IsEnabled=($script:Page -lt $pages-1)
        $pagerVisibility=if ($pages -gt 1) { 'Visible' } else { 'Collapsed' }
        foreach ($key in @('PrevButton','NextButton','PageText')) { $script:Ui[$key].Visibility=$pagerVisibility }
        $script:Ui.CountText.Text=('{0} حساب ذخیره‌شده' -f $Items.Count)
        $key=($script:Page.ToString()+'|'+$script:PageSize+'|'+$Pending+'|'+(($Items | ForEach-Object { $_.Slot.ToString()+':'+$_.State+':'+$_.Email+':'+$_.Updated+':'+$_.IsCurrent }) -join '|'))
        if ($key -eq $script:ListKey) { return }
        $script:ListKey=$key
        $script:Ui.AccountList.Children.Clear()
        if ($Items.Count -eq 0) {
            $empty=[Windows.Controls.TextBlock]::new()
            $empty.Text='هنوز حسابی ذخیره نشده است. «ذخیره نشست فعلی» یا «افزودن حساب» را بزن.'
            $empty.Foreground=[Windows.Media.BrushConverter]::new().ConvertFromString('#9CADC8')
            $empty.FlowDirection='RightToLeft'; $empty.Margin='0,14,0,0'
            $script:Ui.AccountList.Children.Add($empty) | Out-Null
            return
        }
        $first=$script:Page*$script:PageSize
        $last=[Math]::Min($first+$script:PageSize,$Items.Count)
        for ($index=$first; $index -lt $last; $index++) {
            $item=$Items[$index]
            [xml]$rowXaml=@'
<Border xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Background="#141F33" BorderBrush="#2C3B55" BorderThickness="1" CornerRadius="11" Padding="11" Height="68" Margin="0,0,0,8">
 <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="40"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
  <TextBlock x:Name="Number" VerticalAlignment="Center" Foreground="#729DFF" FontSize="17" FontWeight="SemiBold"/>
  <StackPanel Grid.Column="1" VerticalAlignment="Center"><TextBlock x:Name="Email" FontSize="14" FontWeight="SemiBold" TextTrimming="CharacterEllipsis"/><TextBlock x:Name="Info" Foreground="#9CADC8" FontSize="10" Margin="0,3,0,0" TextTrimming="CharacterEllipsis"/></StackPanel>
  <Button x:Name="Login" Grid.Column="2" Content="ورود - در صورت منقضی شدن" FlowDirection="RightToLeft" Background="Transparent" BorderBrush="#35445E" Foreground="#9CADC8" MinWidth="205" Margin="8,0,0,0"/>
  <Button x:Name="Switch" Grid.Column="3" Content="سوییچ به این حساب" Background="#416FE6" BorderBrush="#5682F1" MinWidth="145" Margin="8,0,0,0"/>
 </Grid>
</Border>
'@
            $row=[Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($rowXaml))
            $row.FindName('Number').Text=('{0:00}' -f $item.Slot)
            $row.FindName('Email').Text=if ($item.State -eq 'saved') { $item.Email } else { 'حساب ذخیره‌شده قابل خواندن نیست' }
            $row.FindName('Email').ToolTip=$row.FindName('Email').Text
            $row.FindName('Info').Text=if ($item.IsCurrent) { '● فعال در فایل محلی' } elseif ($item.State -eq 'saved') { 'به‌روزرسانی: '+$item.Updated } else { 'بازنویسی نمی‌شود؛ فایل را بررسی کن.' }
            if ($item.IsCurrent) { $row.BorderBrush=[Windows.Media.BrushConverter]::new().ConvertFromString('#66C99F') }
            $switch=$row.FindName('Switch'); $switch.Tag=$item.Slot; $switch.IsEnabled=($item.State -eq 'saved' -and -not $Pending)
            $login=$row.FindName('Login'); $login.Tag=$item.Slot; $login.IsEnabled=($item.State -eq 'saved' -and -not $Pending)
            $switch.ToolTip='برای جابه‌جایی: Codex پس از تأیید تو بسته می‌شود، حساب عوض می‌شود و Codex دوباره باز می‌شود.'
            $login.ToolTip='فقط اگر ورود این حساب در Codex منقضی شده یا کار نمی‌کند. ورود رسمی را دوباره انجام می‌دهد؛ حساب فعال را عوض نمی‌کند.'
            if ($Pending) { $switch.Visibility='Collapsed'; $login.Visibility='Collapsed' }
            $switch.Add_Click({ param($sender,$eventArgs) Invoke-UiSwitch ([int]$sender.Tag) })
            $login.Add_Click({ param($sender,$eventArgs) Invoke-UiLogin ([int]$sender.Tag) -Existing })
            $script:Ui.AccountList.Children.Add($row) | Out-Null
        }
    }
    function Update-CasUi {
        $state=Get-CasStatus
        $script:Ui.CurrentEmail.Text='نشست محلی پیدا نشد'
        if ($null -ne $state.Current) { $script:Ui.CurrentEmail.Text=$state.Current.Email }
        $script:Ui.ModeText.Text=if ($state.FileMode) { 'وضعیت محلی؛ اعتبار نهایی را داخل کدکس بررسی کن.' } else { 'حالت فایل هنگام نخستین سوییچ آماده می‌شود.' }
        $items=@($state.Slots)
        if (-not $PreviewImage -and -not $script:AutoSized) {
            $script:AutoSized=$true
            $desiredHeight=if ($state.Pending) { 580 } elseif ($items.Count -le 2) { 500 } else { 630 }
            $window.Height=[Math]::Min($desiredHeight,$workArea.Height-24)
        }
        $script:PageSize=if ($state.Pending) { if ($window.Height -lt 570) { 1 } else { 2 } } elseif ($window.Height -lt 540 -and $items.Count -gt 2) { 1 } elseif ($window.Height -lt 630) { 2 } else { 3 }
        Render-CasAccounts $items ([bool]$state.Pending)
        $script:Ui.AddButton.IsEnabled=(-not $state.Pending)
        $script:Ui.SaveCurrentButton.IsEnabled=($null -ne $state.Current -and -not $state.Pending)
        $script:Ui.AddButton.Visibility=if ($state.Pending) { 'Collapsed' } else { 'Visible' }
        $script:Ui.SaveCurrentButton.Visibility=if ($state.Pending) { 'Collapsed' } else { 'Visible' }
        $script:Ui.DeviceCode.Visibility=if ($state.Pending) { 'Collapsed' } else { 'Visible' }
        $script:Ui.OpenButton.IsEnabled=(-not $state.Pending)
        $script:Ui.OpenButton.Visibility=if ($state.Pending) { 'Collapsed' } else { 'Visible' }
        $script:Ui.RecoveryActions.Visibility=if ($state.Pending) { 'Visible' } else { 'Collapsed' }
        $statusColor=if ($state.Pending) { '#F5C77A' } else { '#81D9B3' }
        $script:Ui.StatusText.Foreground=[Windows.Media.BrushConverter]::new().ConvertFromString($statusColor)
        $canKeep=($state.Pending -and $state.FileMode -and $null -ne $state.Current -and @($items | Where-Object { $_.State -eq 'saved' -and $_.Id -eq $state.Current.Id }).Count -gt 0)
        $script:Ui.KeepCurrentButton.IsEnabled=$canKeep
        if ($state.Pending) {
            $script:Ui.StatusText.Text='سوییچ قبلی نیمه‌تمام ثبت شده است؛ حساب‌های ذخیره‌شده پاک نشده‌اند.'
            $script:Ui.StatusHelp.Text=if ($canKeep) { 'اگر در خود Codex هم حسابِ بالای پنجره باز است، «ادامه با حساب فعلی» را بزن؛ Codex بسته نمی‌شود. برای برگشت به وضعیت قبل، کارهایت را ذخیره کن.' } else { 'حساب محلی برای ادامه قابل تأیید نیست. کارهایت را ذخیره کن؛ «بازگشت به قبل» Codex را می‌بندد، فایل‌ها را بازیابی می‌کند و دوباره بازش می‌کند.' }
        } else {
            $script:Ui.StatusHelp.Text='پیش از جابه‌جایی، کارهای باز را ذخیره کن. وضعیت حساب‌ها هر چند ثانیه خودکار بررسی می‌شود.'
        }
    }

    function Show-CasError($Record) {
        $text=[string]$Record.Exception.Message
        if ($text -like 'CAS|*') {
            $parts=$text.Split('|',3)
            $summary=switch ($parts[1]) {
                'LOCK' { 'نسخه قبلی یا پنجره دیگری از سوییچر باز است؛ اول آن را ببند.' }
                'NOAUTH' { 'فایل نشست محلی پیدا نشد. از «+ افزودن حساب» استفاده کن.' }
                'FORMAT' { 'نشست خوانده‌شده پشتیبانی نمی‌شود؛ با دکمه افزودن، ورود رسمی انجام بده.' }
                'DIFFERENT' { 'این ردیف متعلق به حساب دیگری است. برای حساب تازه، «افزودن حساب» را بزن.' }
                'DUPLICATE' { 'این حساب قبلاً ذخیره شده است؛ ردیف همان حساب را انتخاب کن.' }
                'INSTALL' { 'نصب برنامه رسمی کدکس به‌طور دقیق پیدا نشد. برنامه را از منوی Start باز و نصبش را بررسی کن.' }
                'CLI' { 'ابزار رسمی ورود در نصب کدکس پیدا نشد. برنامه رسمی را به‌روز کن؛ چیزی از منبع دیگر نصب نمی‌شود.' }
                'CONFIG' { 'ساختار تنظیمات نیاز به بررسی دارد؛ ابزار آن را حدسی تغییر نداد.' }
                'LOGIN' { 'ورود رسمی کامل نشد یا لغو شد. حساب‌های ذخیره‌شده تغییر نکردند.' }
                'PENDING' { 'سوییچ قبلی کامل نشده؛ از بخش پایین پنجره یکی از دو راهِ ادامه یا بازگشت را انتخاب کن.' }
                'RECOVERY' { 'بازیابی سوییچ نیمه‌تمام در دسترس نیست؛ وضعیت فایل‌ها را بررسی کن.' }
                'ROLLBACK' { 'سوییچ کامل نشد و بازگشت خودکار هم موفق نبود. در بخش پایین پنجره وضعیت حساب فعلی را بررسی کن؛ پشتیبان رمزگذاری‌شده حفظ شده است.' }
                'FILEMODE' { 'حساب فعلی از فایل ورود Codex خوانده نمی‌شود؛ نمی‌توان ادامه با حساب فعلی را تأیید کرد.' }
                'UNSAVED' { 'حساب فعلی با حساب‌های ذخیره‌شده مطابقت ندارد؛ نشان سوییچ نیمه‌تمام حفظ شد.' }
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
        foreach ($key in @('AccountList','AddButton','SaveCurrentButton','PrevButton','NextButton','OpenButton','KeepCurrentButton','RestoreButton','DeviceCode')) { $script:Ui[$key].IsEnabled=$false }
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
            foreach ($key in @('AccountList','AddButton','SaveCurrentButton','PrevButton','NextButton','OpenButton','KeepCurrentButton','RestoreButton','DeviceCode')) { $script:Ui[$key].IsEnabled=$true }
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
    function Invoke-UiLogin([int]$Slot, [switch]$Existing) {
        $title=if ($Existing) { 'ورود دوباره به همین حساب' } else { 'افزودن حساب' }
        $message=if ($Existing) { 'این گزینه برای وقتی است که ورود این حساب در Codex منقضی شده یا کار نمی‌کند. پنجرهٔ ورود رسمی باز می‌شود؛ همان حسابِ این ردیف را انتخاب کن. نشست فعال Codex در این مرحله عوض نمی‌شود.' } else { 'پنجرهٔ ورود رسمی باز می‌شود. حساب موردنظر را در مرورگر بررسی کن. رمز و کد تأیید را فقط در صفحه رسمی وارد کن. نشست فعلی کدکس با این مرحله عوض نمی‌شود.' }
        $answer=[Windows.MessageBox]::Show($window,$message,$title,'OKCancel','Information')
        if ($answer -ne 'OK') { return }
        Invoke-CasUiAction {
            param($Force)
            $account=Add-CasLogin $Slot (Get-UiInstallation) -DeviceCode:([bool]$script:Ui.DeviceCode.IsChecked)
            $script:AutoSized=$false
            $script:Page=[int][Math]::Floor((@((Get-CasStatus).Slots).Count-1)/$script:PageSize)
            $script:Ui.StatusText.Text='ورود حساب ذخیره شد: '+$account.Email+' · برای استفاده، «سوییچ به این حساب» را بزن.'
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
                $script:AutoSized=$false
                $script:Page=[int][Math]::Floor((@((Get-CasStatus).Slots).Count-1)/$script:PageSize)
                $script:Ui.StatusText.Text='ذخیره شد: '+$account.Email
            }
        }
    }

    $script:Ui.AddButton.Add_Click({ Invoke-UiLogin (Get-CasNextSlot) })
    $script:Ui.SaveCurrentButton.Add_Click({
        $state=Get-CasStatus
        if ($null -eq $state.Current) { return }
        if (@($state.Slots | Where-Object { $_.Id -eq $state.Current.Id }).Count -gt 0) {
            $script:Ui.StatusText.Text='این نشست قبلاً در فهرست ذخیره شده است.'
            return
        }
        Invoke-UiImport (Get-CasNextSlot)
    })
    $script:Ui.PrevButton.Add_Click({ $script:Page--; $script:ListKey=''; Update-CasUi })
    $script:Ui.NextButton.Add_Click({ $script:Page++; $script:ListKey=''; Update-CasUi })
    $script:Ui.OpenButton.Add_Click({ Invoke-CasUiAction { param($Force) Start-CasDesktop (Get-UiInstallation); $script:Ui.StatusText.Text='درخواست بازشدن کدکس ارسال شد.' } })
    $script:Ui.KeepCurrentButton.Add_Click({
        $state=Get-CasStatus
        if (-not $state.Pending -or $null -eq $state.Current) { Update-CasUi; return }
        $message='آیا داخل Codex هم همین حساب باز است و اکنون در آن کار می‌کنی؟'+"`n"+$state.Current.Email+"`n`n"+'«ادامه» فقط نشان سوییچ نیمه‌تمام را پاک می‌کند. Codex بسته نمی‌شود و فایل ورود و پروفایل‌ها تغییر نمی‌کنند؛ پشتیبان بازگشت به وضعیت قبل حذف می‌شود.'
        $answer=[Windows.MessageBox]::Show($window,$message,'ادامه با حساب فعلی','YesNo','Question')
        if ($answer -eq 'Yes') {
            Invoke-CasUiAction {
                param($Force)
                $account=Complete-CasPendingWithCurrent
                $script:AutoSized=$false
                $script:Ui.StatusText.Text='حساب فعلی نگه داشته شد: '+$account.Email+' · اکنون می‌توانی بین حساب‌ها جابه‌جا شوی.'
            }
        }
    })
    $script:Ui.RestoreButton.Add_Click({
        $answer=[Windows.MessageBox]::Show($window,'سوییچ قبلی نیمه‌تمام است. کدکس بسته می‌شود، فایل ورود و تنظیمات از پشتیبان پیش از همان سوییچ بازیابی می‌شوند و کدکس دوباره باز می‌شود. ادامه می‌دهی؟','بازگشت به قبل','YesNo','Question')
        if ($answer -eq 'Yes') {
            Invoke-CasUiAction -AllowForce -Action {
                param($Force)
                $installation=Get-UiInstallation
                Stop-CasDesktop $installation -Force:$Force
                Restore-CasTransaction
                Start-CasDesktop $installation
                $script:AutoSized=$false
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
    if ($PreviewImage) {
        $window.Show()
        $window.UpdateLayout()
        & $script:CasPump
        $bitmap=[Windows.Media.Imaging.RenderTargetBitmap]::new([int]$window.ActualWidth,[int]$window.ActualHeight,96,96,[Windows.Media.PixelFormats]::Pbgra32)
        $bitmap.Render($window)
        $encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new()
        $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
        $stream=[IO.File]::Create($PreviewImage)
        try { $encoder.Save($stream) } finally { $stream.Dispose() }
        $window.Close()
    } else { $null=$window.ShowDialog() }
    $timer.Stop()
} catch {
    if ($PreviewImage) { Write-Error $_.Exception.ToString(); exit 1 }
    $null=[Windows.MessageBox]::Show(('The window could not run. Error type: '+$_.Exception.GetType().Name),'Codex Switch','OK','Error')
} finally { Close-Cas }
