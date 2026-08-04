package expo.modules.wakeword.commands

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.ContactsContract
import android.util.Log
import java.util.Locale
import java.util.regex.Pattern

internal object CommunicationCommandHandler {
    fun canHandle(lower: String, command: String): Boolean {
        return "call" in lower || "dial" in lower || "message" in lower || "sms" in lower || "text" in lower
    }

    fun handle(command: String, lower: String, context: Context): String {
        return if ("message" in lower || "sms" in lower || "text" in lower) {
            handleSMS(command, lower, context)
        } else {
            handleCall(command, lower, context)
        }
    }

    private fun handleSMS(command: String, lower: String, context: Context): String {
        val smsRegex = Pattern.compile("(?:send\\s+)?(?:message|sms|text)\\s+(?:to\\s+)?([a-zA-Z\\s]+?)\\s+(?:saying|that|with)\\s+(.+)", Pattern.CASE_INSENSITIVE)
        val match = smsRegex.matcher(command)
        var contactName = ""
        var messageBody = ""
        if (match.find()) {
            contactName = match.group(1)?.trim() ?: ""
            messageBody = match.group(2)?.trim() ?: ""
        } else {
            val simpleRegex = Pattern.compile("^text\\s+([a-zA-Z]+)\\s+(.+)", Pattern.CASE_INSENSITIVE)
            val matchSimple = simpleRegex.matcher(command)
            if (matchSimple.find()) {
                contactName = matchSimple.group(1)?.trim() ?: ""
                messageBody = matchSimple.group(2)?.trim() ?: ""
            }
        }

        return if (contactName.isNotEmpty()) {
            var number = ""
            var resolvedName = ""
            try {
                val uri = ContactsContract.CommonDataKinds.Phone.CONTENT_URI
                val projection = arrayOf(
                    ContactsContract.CommonDataKinds.Phone.NUMBER,
                    ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME
                )
                val cursor = context.contentResolver.query(uri, projection, null, null, null)
                cursor?.use {
                    val nameIdx = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
                    val numIdx = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
                    val query = contactName.lowercase(Locale.US).trim()
                    while (it.moveToNext()) {
                        val displayName = it.getString(nameIdx) ?: ""
                        val lowerDisplay = displayName.lowercase(Locale.US).trim()
                        if (lowerDisplay == query || lowerDisplay.contains(query) || query.contains(lowerDisplay)) {
                            number = it.getString(numIdx) ?: ""
                            resolvedName = displayName
                            break
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e("CommunicationCommand", "Error reading contacts for SMS", e)
            }

            try {
                val smsUri = Uri.parse("smsto:$number")
                val intent = Intent(Intent.ACTION_SENDTO, smsUri).apply {
                    putExtra("sms_body", messageBody)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(intent)
                if (resolvedName.isNotEmpty()) {
                    "Opening text composer to $resolvedName."
                } else {
                    "Opening text composer to $contactName."
                }
            } catch (e: Exception) {
                "Failed to open SMS composer."
            }
        } else {
            "Who would you like to message, and what should I say?"
        }
    }

    private fun handleCall(command: String, lower: String, context: Context): String {
        val contactName = command.replace(Regex("^(call|dial)\\s+", RegexOption.IGNORE_CASE), "").replace(Regex("\\bcontacts?\\b", RegexOption.IGNORE_CASE), "").trim()
        return if (contactName.isNotEmpty()) {
            var number = ""
            var resolvedName = ""
            try {
                val uri = ContactsContract.CommonDataKinds.Phone.CONTENT_URI
                val projection = arrayOf(
                    ContactsContract.CommonDataKinds.Phone.NUMBER,
                    ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME
                )
                val cursor = context.contentResolver.query(uri, projection, null, null, null)
                cursor?.use {
                    val nameIdx = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
                    val numIdx = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
                    val query = contactName.lowercase(Locale.US).trim()
                    while (it.moveToNext()) {
                        val displayName = it.getString(nameIdx) ?: ""
                        val lowerDisplay = displayName.lowercase(Locale.US).trim()
                        if (lowerDisplay == query || lowerDisplay.contains(query) || query.contains(lowerDisplay)) {
                            number = it.getString(numIdx) ?: ""
                            resolvedName = displayName
                            break
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e("CommunicationCommand", "Error querying contacts for call", e)
            }

            if (number.isNotEmpty()) {
                try {
                    val hasCallPermission = context.checkSelfPermission(android.Manifest.permission.CALL_PHONE) == PackageManager.PERMISSION_GRANTED
                    val intent = if (hasCallPermission) {
                        Intent(Intent.ACTION_CALL, Uri.parse("tel:$number")).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                    } else {
                        Intent(Intent.ACTION_DIAL, Uri.parse("tel:$number")).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                    }
                    context.startActivity(intent)
                    "Calling ${resolvedName.ifEmpty { contactName }}."
                } catch (e: Exception) {
                    "Failed to make call."
                }
            } else {
                "Sorry, I couldn't find a contact named $contactName."
            }
        } else {
            "Who would you like to call?"
        }
    }
}
