package com.nuans.nuans

import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.provider.OpenableColumns
import androidx.core.content.FileProvider

class NuansFileProvider : FileProvider() {
    override fun getType(uri: Uri): String {
        val name = uri.lastPathSegment.orEmpty().lowercase()
        if (name.endsWith(".nuans") || name.endsWith(".nuansform")) return "application/nuans"
        if (name.endsWith(".zip")) return "application/zip"
        return super.getType(uri) ?: "application/nuans"
    }

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?,
    ): Cursor {
        val inner = super.query(uri, projection, selection, selectionArgs, sortOrder)
        val displayName = displayNameOf(uri)
        if (inner == null) {
            return MatrixCursor(arrayOf(OpenableColumns.DISPLAY_NAME)).apply {
                addRow(arrayOf(displayName))
            }
        }
        val cols = inner.columnNames
        val matrix = MatrixCursor(cols)
        inner.use { cursor ->
            while (cursor.moveToNext()) {
                val row = Array<Any?>(cols.size) { index ->
                    if (cols[index] == OpenableColumns.DISPLAY_NAME) {
                        displayName
                    } else {
                        when (cursor.getType(index)) {
                            Cursor.FIELD_TYPE_INTEGER -> cursor.getLong(index)
                            Cursor.FIELD_TYPE_FLOAT -> cursor.getDouble(index)
                            Cursor.FIELD_TYPE_STRING -> cursor.getString(index)
                            Cursor.FIELD_TYPE_BLOB -> cursor.getBlob(index)
                            else -> null
                        }
                    }
                }
                matrix.addRow(row)
            }
        }
        return matrix
    }

    private fun displayNameOf(uri: Uri): String {
        val raw = (uri.lastPathSegment ?: "Nuans_formu").substringAfterLast('/')
        if (raw.lowercase().endsWith(".zip")) {
            val base = raw.replace(Regex("\\.zip$", RegexOption.IGNORE_CASE), "")
                .replace(Regex("[\\\\/:*?\"<>|]"), "_")
                .ifBlank { "Nuans_formu" }
            return "$base.zip"
        }
        var base = raw
            .replace(Regex("\\.nuansform$", RegexOption.IGNORE_CASE), "")
            .replace(Regex("\\.nuans$", RegexOption.IGNORE_CASE), "")
            .replace(Regex("[\\\\/:*?\"<>|]"), "_")
            .replace(Regex("\\s+"), "_")
            .ifBlank { "Nuans_formu" }
        return if (base.endsWith(".nuans", ignoreCase = true)) base else "$base.nuans"
    }
}
