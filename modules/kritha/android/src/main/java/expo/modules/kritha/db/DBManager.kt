package expo.modules.kritha.db

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.util.Log

object DBManager {
    private const val TAG = "DBManager"
    private const val DB_NAME = "kritha.db"
    private const val DB_VERSION = 3

    @Volatile
    private var helper: DBHelper? = null

    private class DBHelper(context: Context) : SQLiteOpenHelper(context, DB_NAME, null, DB_VERSION) {
        override fun onCreate(db: SQLiteDatabase) {
            db.execSQL("""
                CREATE TABLE IF NOT EXISTS sessions (
                    id TEXT PRIMARY KEY,
                    title TEXT NOT NULL,
                    pinned INTEGER NOT NULL DEFAULT 0,
                    archived INTEGER NOT NULL DEFAULT 0,
                    created_at INTEGER NOT NULL
                )
            """.trimIndent())

            db.execSQL("""
                CREATE TABLE IF NOT EXISTS messages (
                    id TEXT PRIMARY KEY,
                    session_id TEXT NOT NULL,
                    role TEXT NOT NULL,
                    text TEXT NOT NULL,
                    created_at INTEGER NOT NULL,
                    FOREIGN KEY (session_id) REFERENCES sessions (id) ON DELETE CASCADE
                )
            """.trimIndent())
        }


        override fun onConfigure(db: SQLiteDatabase) {
            super.onConfigure(db)
            db.setForeignKeyConstraintsEnabled(true)
            db.enableWriteAheadLogging()
        }

        override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
            if (oldVersion < 2) {
                db.execSQL("ALTER TABLE sessions ADD COLUMN archived INTEGER NOT NULL DEFAULT 0")
            }
            if (oldVersion < 3) {
                db.execSQL("ALTER TABLE sessions ADD COLUMN pinned INTEGER NOT NULL DEFAULT 0")
            }
        }
    }

    @Synchronized
    fun init(context: Context) {
        if (helper == null) {
            try {
                helper = DBHelper(context.applicationContext).apply {
                    writableDatabase
                }
                Log.d(TAG, "DBManager initialized successfully with WAL and FK enabled")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to initialize DBManager", e)
                throw e
            }
        }
    }

    private fun getDb(): SQLiteDatabase {
        return helper?.writableDatabase
            ?: throw IllegalStateException("DBManager is not initialized. Call DBManager.init(context) first.")
    }

    @Synchronized
    fun getSessions(): List<Map<String, Any>> {
        val list = mutableListOf<Map<String, Any>>()
        val cursor = getDb().rawQuery("SELECT id, title, pinned, archived, created_at FROM sessions ORDER BY created_at DESC", null)
        cursor.use { c ->
            val idIdx = c.getColumnIndexOrThrow("id")
            val titleIdx = c.getColumnIndexOrThrow("title")
            val pinnedIdx = c.getColumnIndexOrThrow("pinned")
            val archivedIdx = c.getColumnIndexOrThrow("archived")
            val createdIdx = c.getColumnIndexOrThrow("created_at")
            while (c.moveToNext()) {
                list.add(
                    mapOf(
                        "id" to c.getString(idIdx),
                        "title" to c.getString(titleIdx),
                        "pinned" to c.getInt(pinnedIdx),
                        "archived" to c.getInt(archivedIdx),
                        "created_at" to c.getLong(createdIdx),
                    )
                )
            }
        }
        return list
    }

    @Synchronized
    fun createSession(title: String, customId: String? = null): Map<String, Any> {
        val id = if (!customId.isNullOrBlank()) customId else System.currentTimeMillis().toString()
        val createdAt = System.currentTimeMillis()
        val cv = ContentValues().apply {
            put("id", id)
            put("title", title)
            put("created_at", createdAt)
        }
        getDb().insertWithOnConflict("sessions", null, cv, SQLiteDatabase.CONFLICT_REPLACE)
        return mapOf(
            "id" to id,
            "title" to title,
            "created_at" to createdAt
        )
    }

    @Synchronized
    fun updateSessionTitle(id: String, title: String) {
        val cv = ContentValues().apply {
            put("title", title)
        }
        getDb().update("sessions", cv, "id = ?", arrayOf(id))
    }

    @Synchronized
    fun setSessionPinned(id: String, pinned: Boolean) {
        val cv = ContentValues().apply {
            put("pinned", if (pinned) 1 else 0)
        }
        getDb().update("sessions", cv, "id = ?", arrayOf(id))
    }

    @Synchronized
    fun setSessionArchived(id: String, archived: Boolean) {
        val cv = ContentValues().apply {
            put("archived", if (archived) 1 else 0)
        }
        getDb().update("sessions", cv, "id = ?", arrayOf(id))
    }

    @Synchronized
    fun deleteSession(id: String) {
        getDb().delete("sessions", "id = ?", arrayOf(id))
    }

    @Synchronized
    fun getMessages(sessionId: String): List<Map<String, Any>> {
        val list = mutableListOf<Map<String, Any>>()
        val cursor = getDb().rawQuery(
            "SELECT id, session_id, role, text, created_at FROM messages WHERE session_id = ? ORDER BY created_at ASC",
            arrayOf(sessionId)
        )
        cursor.use { c ->
            val idIdx = c.getColumnIndexOrThrow("id")
            val sessIdx = c.getColumnIndexOrThrow("session_id")
            val roleIdx = c.getColumnIndexOrThrow("role")
            val textIdx = c.getColumnIndexOrThrow("text")
            val createdIdx = c.getColumnIndexOrThrow("created_at")
            while (c.moveToNext()) {
                list.add(
                    mapOf(
                        "id" to c.getString(idIdx),
                        "session_id" to c.getString(sessIdx),
                        "role" to c.getString(roleIdx),
                        "text" to c.getString(textIdx),
                        "created_at" to c.getLong(createdIdx)
                    )
                )
            }
        }
        return list
    }

    @Synchronized
    fun addMessage(
        id: String? = null,
        sessionId: String,
        role: String,
        text: String,
        createdAt: Long? = null
    ): Map<String, Any> {
        val msgId = if (!id.isNullOrBlank()) id else "${System.currentTimeMillis()}_$role"
        val time = createdAt ?: System.currentTimeMillis()
        val cv = ContentValues().apply {
            put("id", msgId)
            put("session_id", sessionId)
            put("role", role)
            put("text", text)
            put("created_at", time)
        }
        getDb().insertWithOnConflict("messages", null, cv, SQLiteDatabase.CONFLICT_REPLACE)
        return mapOf(
            "id" to msgId,
            "session_id" to sessionId,
            "role" to role,
            "text" to text,
            "created_at" to time
        )
    }

    @Synchronized
    fun updateMessage(id: String, text: String) {
        val cv = ContentValues().apply {
            put("text", text)
        }
        getDb().update("messages", cv, "id = ?", arrayOf(id))
    }

    @Synchronized
    fun prepareTurn(sessionId: String?, userText: String): Map<String, Any> {
        val targetSessionId = if (sessionId.isNullOrBlank()) System.currentTimeMillis().toString() else sessionId
        val now = System.currentTimeMillis()
        var sessionCreated = false
        var sessionTitle = ""
        var sessionCreatedAt = 0L

        val db = getDb()
        db.beginTransaction()
        try {
            val existingSessions = getSessions()
            val sessionExists = existingSessions.any { it["id"] == targetSessionId }
            
            if (!sessionExists) {
                sessionTitle = if (userText.length > 25) userText.take(25) + "..." else if (userText.isNotBlank()) userText else "New Chat"
                sessionCreatedAt = now
                val cv = ContentValues().apply {
                    put("id", targetSessionId)
                    put("title", sessionTitle)
                    put("created_at", sessionCreatedAt)
                }
                db.insertWithOnConflict("sessions", null, cv, SQLiteDatabase.CONFLICT_REPLACE)
                sessionCreated = true
            } else if (userText.isNotBlank()) {
                val messages = getMessages(targetSessionId)
                if (messages.isEmpty()) {
                    sessionTitle = if (userText.length > 25) userText.take(25) + "..." else userText
                    val cv = ContentValues().apply {
                        put("title", sessionTitle)
                    }
                    db.update("sessions", cv, "id = ?", arrayOf(targetSessionId))
                }
            }

            var userMessageId = ""
            if (userText.isNotBlank()) {
                userMessageId = "${now}_user"
                val cvUser = ContentValues().apply {
                    put("id", userMessageId)
                    put("session_id", targetSessionId)
                    put("role", "user")
                    put("text", userText)
                    put("created_at", now)
                }
                db.insertWithOnConflict("messages", null, cvUser, SQLiteDatabase.CONFLICT_REPLACE)
            }

            db.setTransactionSuccessful()
            return mapOf(
                "sessionId" to targetSessionId,
                "sessionCreated" to sessionCreated,
                "sessionTitle" to sessionTitle,
                "sessionCreatedAt" to sessionCreatedAt,
                "userMessageId" to userMessageId,
                "userMessageCreatedAt" to now
            )
        } catch (e: Exception) {
            Log.e(TAG, "Failed transaction preparing turn for session $targetSessionId", e)
            throw e
        } finally {
            db.endTransaction()
        }
    }

    @Synchronized
    fun saveAssistantResponse(sessionId: String, assistantText: String, messageId: String? = null): Map<String, Any> {
        if (assistantText.isBlank()) return emptyMap()
        val db = getDb()
        val now = System.currentTimeMillis()
        val finalMessageId = messageId ?: "${now}_assistant"
        
        val cvAssistant = ContentValues().apply {
            put("id", finalMessageId)
            put("session_id", sessionId)
            put("role", "assistant")
            put("text", assistantText)
            put("created_at", now)
        }
        db.insertWithOnConflict("messages", null, cvAssistant, SQLiteDatabase.CONFLICT_REPLACE)
        
        return mapOf(
            "id" to finalMessageId,
            "created_at" to now
        )
    }

    @Synchronized
    fun saveConversationTurn(sessionId: String, userText: String, assistantText: String) {
        if (userText.isBlank() && assistantText.isBlank()) return
        val targetSessionId = if (sessionId.isBlank()) System.currentTimeMillis().toString() else sessionId

        val db = getDb()
        db.beginTransaction()
        try {
            val existingSessions = getSessions()
            val sessionExists = existingSessions.any { it["id"] == targetSessionId }
            if (!sessionExists) {
                val title = if (userText.length > 25) userText.take(25) + "..." else if (userText.isNotBlank()) userText else "New Chat"
                val cv = ContentValues().apply {
                    put("id", targetSessionId)
                    put("title", title)
                    put("created_at", System.currentTimeMillis())
                }
                db.insertWithOnConflict("sessions", null, cv, SQLiteDatabase.CONFLICT_REPLACE)
            } else if (userText.isNotBlank()) {
                val messages = getMessages(targetSessionId)
                if (messages.isEmpty()) {
                    val title = if (userText.length > 25) userText.take(25) + "..." else userText
                    val cv = ContentValues().apply {
                        put("title", title)
                    }
                    db.update("sessions", cv, "id = ?", arrayOf(targetSessionId))
                }
            }

            val now = System.currentTimeMillis()
            if (userText.isNotBlank()) {
                val cvUser = ContentValues().apply {
                    put("id", "${now}_user")
                    put("session_id", targetSessionId)
                    put("role", "user")
                    put("text", userText)
                    put("created_at", now)
                }
                db.insertWithOnConflict("messages", null, cvUser, SQLiteDatabase.CONFLICT_REPLACE)
            }
            if (assistantText.isNotBlank()) {
                val cvAssistant = ContentValues().apply {
                    put("id", "${now + 1}_assistant")
                    put("session_id", targetSessionId)
                    put("role", "assistant")
                    put("text", assistantText)
                    put("created_at", now + 1)
                }
                db.insertWithOnConflict("messages", null, cvAssistant, SQLiteDatabase.CONFLICT_REPLACE)
            }

            db.setTransactionSuccessful()
            Log.d(TAG, "Successfully saved conversation turn in transaction for session $targetSessionId")
        } catch (e: Exception) {
            Log.e(TAG, "Failed transaction saving conversation turn for session $targetSessionId", e)
            throw e
        } finally {
            db.endTransaction()
        }
    }
}
