<?php include '../phpinclude/init.php';?>
<?php include '../phpinclude/begin.php';?>

<?php
// jump if already signed in
if (isset($S)) {
    echo "<script>location.href='/account/profile.php';</script>";
    exit();
}
?>

<script
	src="https://www.google.com/recaptcha/api.js?onload=recaptchaCallback&render=explicit"
	async defer></script>

<?php
$message1 = "&nbsp;";
$message2 = "&nbsp;";
$message3 = "&nbsp;";
$messagerc = "&nbsp;";

if (isset($_GET['msg1'])) {
    $message1 = check_legal_chars($_GET['msg1']);
}
if (isset($_GET['msg2'])) {
    $message2 = check_legal_chars($_GET['msg2']);
}
if (isset($_GET['msg3'])) {
    $message3 = check_legal_chars($_GET['msg3']);
}
if (isset($_GET['msgrc'])) {
    $messagerc = check_legal_chars($_GET['msgrc']);
}
?>

<div class="titletext">Sign Up for an Account</div>

<table width="500">
	<form name="signupform" id="signupform" action="signup2.php"
		method="post" enctype="application/x-www-form-urlencoded">
		<tr>
			<td colspan='3'>&nbsp;</td>
		</tr>
		<tr>
			<td align="right"><b>Email:</b></td>
			<td align="left" valign="middle"><input type="Text" name="emailsu"
				id="emailsu" value="" maxlength="255"
				onchange="$('#msg3').html('');"></td>
			<td align="left">&nbsp;</td>
		</tr>
		<tr>
			<td align="right"><b>Confirm:</b></td>
			<td align="left" valign="middle"><input type="Text" name="emailsu2"
				id="emailsu2" value="" maxlength="255"
				onchange="$('#msg3').html('');"></td>
			<td></td>
		</tr>
		<tr>
			<td>&nbsp;</td>
			<td colspan='2'><div id="msg3" class="errmessage"><?php echo $message3;?></div></td>
		</tr>
		<tr>
			<td align="right"><b>Password:</b></td>
			<td align="left"><input type="Password" name="passwordsu"
				id="passwordsu" maxlength="32" onchange="$('#msg2').html('');"></td>
			<td align="left">[at least 6 characters]</td>
		</tr>
		<tr>
			<td align="right"><b>Confirm:</b></td>
			<td colspan="2" align="left"><input type="Password"
				name="passwordsu2" id="passwordsu2" maxlength="32"
				onchange="$('#msg2').html('');"></td>
		</tr>
		<tr>
			<td>&nbsp;</td>
			<td colspan='2'><div id="msg2" class="errmessage"><?php echo $message2;?></div></td>
		</tr>
		<tr>
			<td align="right"><b>Username:</b></td>
			<td align="left" valign="middle"><input type="Text" name="usernamesu"
				id="usernamesu" value="" maxlength="16"
				onchange="$('#msg').html('');"></td>
			<td><input type="button" name="button_su1" value="CHECK"
				onclick="do_check_signup(0);"></td>
		</tr>
		<tr>
			<td>&nbsp;</td>
			<td colspan='2'><div id="msg" class="errmessage"><?php echo $message1;?></div></td>
		</tr>

		<tr>
			<td align="right"><b>Terms:</b></td>
			<td colspan='2' align="left"><input type="checkbox" id="terms"
				name="terms" value="1"> I accept the <a href="/public/terms.php"
				target="external">Terms and Conditions</a></td>
		</tr>
		<tr>
			<td>&nbsp;</td>
			<td colspan='2'><div id="msg4" class="errmessage">&nbsp;</div></td>
		</tr>

		<tr>
			<td align="right" valign="top"><b>reCAPTCHA:</b></td>
			<td colspan='2'><div id="recaptcha"></div></td>
			<input type="hidden" name="rcc" id="rcc" value="">
			<input type="hidden" name="rcr" id="rcr" value="">
			<input type="hidden" name="rch" id="rch" value="">
		</tr>
		<tr>
			<td>&nbsp;</td>
			<td colspan='2'>
				<div id="msgrc" class="errmessage"><?php echo $messagerc;?></div>
			</td>
		</tr>
		<tr>
			<td colspan='3' align="center"><br> <input type="button"
				value="SIGN UP NOW" onclick="check_submit();"></td>
		</tr>

	</form>
</table>

<br>
<br>

<script type="text/javascript">
	var recaptchaCallback = function () {
		console.log('recaptcha is ready'); // showing
		grecaptcha.render("recaptcha", {
			sitekey: "<?php echo $global_recaptcha_publickey;?>",
			callback: function () {
				console.log('recaptcha callback');
			}
		});
	}
</script>

<?php include '../phpinclude/end.php';?>

