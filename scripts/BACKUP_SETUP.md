# Backup — `backup_school_inventory.sh`

One command makes a timestamped archive in `/mnt/storage/project_backups/school_inventory_app_backup`
(30-day retention), uploads it to the Google Drive folder
https://drive.google.com/drive/folders/1WTCRykRcQpp8XO2xiBr31xDvDD8RDW9E (rclone remote `gdrive`,
already configured on homi-nas), and commits + pushes to `AwaizFatima08/school_inventory_app`.

```bash
/mnt/storage/projects/school_inventory_app/scripts/backup_school_inventory.sh
```

It backs up source code only. The archive includes `android/app/google-services.json` (kept out of the
public git repo). Firestore data backups are separate (Firebase console → Firestore → Disaster recovery;
scheduled backups need the Blaze plan).
