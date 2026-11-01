"""Page bodies for the School Inventory website."""

UPDATED = '1 November 2026'

PLAY_LINK = ''

HOME = '''
<section class="hero"><div class="wrap">
<div>
<h1>Your janitorial stock register, without the paper</h1>
<p class="lead">School Inventory follows the way your school already works. Staff bring a slip, the supervisor enters it, the incharge approves, and stock updates itself when items are issued.</p>
<p class="actions"><a class="btn" href="/app/">Open the web app</a>__PLAY__</p>
<p class="note">Works on Android phones and in a desktop browser, with the same account and the same data.</p>
</div>
<img class="shot" src="/screen-desktop.png" alt="School Inventory dashboard on a desktop browser" width="1280" height="802">
</div></section>

<section><div class="wrap">
<h2>How it works</h2>
<ol class="steps">
<li><strong>Demand</strong>Janitorial staff bring their paper slip. The supervisor enters it against their name.</li>
<li><strong>Approve</strong>The incharge sees it, can reduce quantities, and approves or rejects it.</li>
<li><strong>Issue</strong>The supervisor hands over the items. Stock goes down and the history records who, what and when.</li>
</ol>
</div></section>

<section class="tint"><div class="wrap">
<h2>What you get</h2>
<ul class="grid">
<li><strong>Live stock</strong>The balance of every item, with low-stock warnings at the level you set.</li>
<li><strong>Stock received</strong>Purchases and opening stock are added only after the incharge approves them.</li>
<li><strong>Full history</strong>Every movement is recorded and cannot be edited, so the register stays honest.</li>
<li><strong>Physical counts</strong>Correct stock after a count, with the reason recorded.</li>
<li><strong>Monthly reports</strong>Issued per item and per staff member, with a CSV export for Excel.</li>
<li><strong>Your own items</strong>Start from a standard janitorial list and add whatever your school keeps.</li>
</ul>
</div></section>

<section><div class="wrap">
<h2>Who does what</h2>
<ul class="grid three">
<li><strong>Janitorial staff</strong>No phone or login needed. They keep using paper slips and are listed by name.</li>
<li><strong>Supervisor</strong>Enters slips, records stock received, issues items and keeps the item list.</li>
<li><strong>Incharge</strong>Approves demands and receipts, corrects stock after a count, and sees reports.</li>
</ul>
<p>When the incharge changes, the school admin reassigns the role in a moment and all the history stays.</p>
</div></section>

<section class="tint"><div class="wrap">
<h2>Getting started</h2>
<ol class="steps">
<li><strong>Create your school</strong>The first person signs up and becomes the admin.</li>
<li><strong>Invite your team</strong>Share the 6-letter school code. The admin approves each person.</li>
<li><strong>Enter opening stock</strong>Record what is on the shelf today and start using it.</li>
</ol>
<p class="actions"><a class="btn" href="/app/">Open the web app</a></p>
</div></section>
'''

PRIVACY = f'''
<article class="wrap doc">
<h1>Privacy Policy</h1>
<p class="meta">Last updated: {UPDATED}</p>
<p>School Inventory ("the app") is made by HomiLabs ("we", "us"). It helps schools keep track of janitorial stock. This policy explains what is collected, why, where it is stored and what you can do about it. It covers the Android app and the web app at school-supplies.homilabs.org.</p>

<h2>The short version</h2>
<ul>
<li>We collect only what is needed to run your school's stock register.</li>
<li>The app has <strong>no ads and no analytics or advertising trackers</strong>.</li>
<li>We do not sell your data or share it with advertisers.</li>
<li>Only approved members of your school can see your school's records.</li>
<li>You can delete your account inside the app at any time.</li>
</ul>

<h2>What we collect</h2>
<h3>Your account</h3>
<p>Your name, your email address and a password. The password is handled by Google Firebase Authentication and we never see it. We also keep your role in the school (for example supervisor or incharge) and whether you are an admin.</p>
<h3>School records</h3>
<ul>
<li><strong>Janitorial staff records</strong> entered by the school: name, and optionally employee number, phone number and duty area. These people do not use the app. The school decides what to enter and is responsible for having the right to record it.</li>
<li><strong>Stock records:</strong> items, quantities, demand slips, stock received, count corrections and the history of movements, including the names of the people who entered, approved or issued them and any notes they wrote.</li>
</ul>
<h3>Technical data</h3>
<p>To keep accounts secure and the service working, Google Firebase processes technical data such as IP address, device and browser information and security tokens.</p>
<p>The app does not ask for your location, contacts, camera, photos or files.</p>

<h2>Why we use it</h2>
<ul>
<li>To sign you in and show you your school's records.</li>
<li>To run the demand, approval and issue process and keep its history.</li>
<li>To keep the service secure and to answer you when you contact us.</li>
</ul>

<h2>Where it is stored and who can see it</h2>
<p>Data is stored with Google Firebase. School records are held in Google's Mumbai, India region (asia-south1), and login data is handled by Firebase Authentication. Data is encrypted in transit and at rest. Google acts as our service provider.</p>
<p>Inside the app, your school's records can be read only by approved members of that school. Your school's admin decides who is approved and what role they have. We may access data only where needed to give support you ask for, to keep the service secure or if the law requires it.</p>

<h2>How long we keep it</h2>
<p>Account data is kept until you delete your account. School records are kept while the school uses the app, because they are its audit trail. A school's admin can ask us to delete the whole school by email.</p>

<h2>Your choices and rights</h2>
<ul>
<li><strong>Correct:</strong> ask your school's supervisor or admin to fix records, or email us.</li>
<li><strong>Export:</strong> members with access to reports can download monthly records as a CSV file.</li>
<li><strong>Delete:</strong> see <a href="/delete-account.html">how to delete your account</a>.</li>
<li>Depending on where you live, you may have further rights under local data-protection law. Contact us to use them.</li>
</ul>
<p>Janitorial staff listed in a school's records should contact the school. We will also help where we can.</p>

<h2>Children</h2>
<p>The app is for adult school staff. It is not designed for children and should not be used to record information about pupils.</p>

<h2>Changes</h2>
<p>If we change this policy we will update this page and its date. If a change is significant we will tell you in the app.</p>

<h2>Contact</h2>
<p>HomiLabs, <a href="mailto:support@homilabs.org">support@homilabs.org</a></p>
</article>
'''

TERMS = f'''
<article class="wrap doc">
<h1>Terms of Use</h1>
<p class="meta">Last updated: {UPDATED}</p>
<p>By creating an account or using School Inventory ("the app"), made by HomiLabs, you accept these terms.</p>

<h2>1. What the app does</h2>
<p>The app helps a school record janitorial stock: demands, approvals, issues, stock received and reports. It is a record-keeping tool. The school remains responsible for its stock, its decisions and the accuracy of what it enters.</p>

<h2>2. Accounts</h2>
<p>You need an account to use the app, and you must keep your password private. The first person to set up a school becomes its admin and decides who joins it and what role they have. A school's data belongs to the school.</p>

<h2>3. Acceptable use</h2>
<p>Use the app only for legitimate school record-keeping. Do not enter information you have no right to record, do not record information about pupils, and do not try to access other schools' data, disrupt the service or bypass its security.</p>

<h2>4. Availability</h2>
<p>We aim to keep the service available but cannot promise it will always work without interruption. It needs an internet connection and depends on Google Firebase. Keep your own copies of records you must retain, using the CSV export.</p>

<h2>5. Liability</h2>
<p>The app is provided "as is". To the fullest extent the law allows, HomiLabs is not liable for indirect or consequential loss, or for stock differences or decisions based on what is recorded in the app. Nothing in these terms limits liability that cannot be limited by law.</p>

<h2>6. Ending</h2>
<p>You can stop at any time and <a href="/delete-account.html">delete your account</a>. We may suspend accounts that misuse the service.</p>

<h2>7. Changes and law</h2>
<p>We may update these terms. If a change is significant we will tell you in the app first. These terms are governed by the laws of Pakistan, without affecting any mandatory rights you have where you live.</p>

<h2>8. Contact</h2>
<p>HomiLabs, <a href="mailto:support@homilabs.org">support@homilabs.org</a></p>
</article>
'''

DELETION = f'''
<article class="wrap doc">
<h1>Delete your School Inventory account</h1>
<p class="meta">Last updated: {UPDATED}</p>
<p>School Inventory is made by HomiLabs. There are two ways to delete your account.</p>

<h2>Option 1: in the app (fastest)</h2>
<ol>
<li>Open School Inventory on your phone or in the web app and sign in.</li>
<li>Go to <strong>More</strong> and tap <strong>Delete my account</strong>. (If you have not joined a school yet, the same option is on your first screen.)</li>
<li>Enter your password and confirm.</li>
</ol>
<p>Your account is removed straight away and cannot be recovered. If you are your school's only admin and other members remain, the app asks you to make someone else an admin first, so the school is not left without one.</p>

<h2>Option 2: by email</h2>
<p>If you can no longer use the app, email <a href="mailto:support@homilabs.org?subject=Delete%20my%20School%20Inventory%20account">support@homilabs.org</a> from the address on your account, with the subject "Delete my School Inventory account". We will confirm it is you and delete the account within 30 days, usually much sooner.</p>

<h2>What is deleted and what stays</h2>
<ul>
<li><strong>Deleted:</strong> your login, your email address, your profile and your membership of the school.</li>
<li><strong>Kept by the school:</strong> stock records you entered, approved or issued, which show your name. They are the school's audit trail and remain for as long as the school keeps using the app.</li>
</ul>

<h2>Deleting a whole school</h2>
<p>A school's admin can email us to delete the school and all its records. Once we confirm the request, this is done within 30 days.</p>
</article>
'''

HOME = HOME.replace('__PLAY__', PLAY_LINK)
