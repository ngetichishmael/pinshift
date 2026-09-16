package com.pinshift.pinshift

import java.util.concurrent.CopyOnWriteArrayList

object SimulationHub {
    @Volatile
    var snapshot: Map<String, Any?> = emptyMap()
        private set

    private val listeners = CopyOnWriteArrayList<(Map<String, Any?>) -> Unit>()

    fun publish(next: Map<String, Any?>) {
        snapshot = next
        for (listener in listeners) {
            listener(next)
        }
    }

    fun addListener(listener: (Map<String, Any?>) -> Unit) {
        listeners.add(listener)
    }

    fun removeListener(listener: (Map<String, Any?>) -> Unit) {
        listeners.remove(listener)
    }
}
