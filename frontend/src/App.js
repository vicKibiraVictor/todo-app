import React, { useState, useEffect } from "react";
import axios from "axios";

const API = "";  // nginx proxies /api/ -> backend, works everywhere

const PRIORITY_CONFIG = {
  high:   { label: "High",   color: "#e74c3c", bg: "#fdecea" },
  medium: { label: "Medium", color: "#f39c12", bg: "#fef9ec" },
  low:    { label: "Low",    color: "#27ae60", bg: "#eafaf1" },
};

export default function App() {
  const [todos, setTodos] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [showForm, setShowForm] = useState(false);
  const [editTodo, setEditTodo] = useState(null);
  const [filter, setFilter] = useState("all");
  const [form, setForm] = useState({ title: "", description: "", priority: "medium" });

  const fetchTodos = async () => {
    try {
      const res = await axios.get(`${API}/api/todos`);
      setTodos(res.data);
      setError(null);
    } catch {
      setError("Cannot connect to server. Is the backend running?");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { fetchTodos(); }, []);

  const openCreate = () => {
    setEditTodo(null);
    setForm({ title: "", description: "", priority: "medium" });
    setShowForm(true);
  };

  const openEdit = (todo) => {
    setEditTodo(todo);
    setForm({ title: todo.title, description: todo.description, priority: todo.priority });
    setShowForm(true);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!form.title.trim()) return;
    try {
      if (editTodo) {
        await axios.put(`${API}/api/todos/${editTodo.id}`, form);
      } else {
        await axios.post(`${API}/api/todos`, form);
      }
      setShowForm(false);
      fetchTodos();
    } catch {
      alert("Failed to save todo");
    }
  };

  const toggleComplete = async (todo) => {
    await axios.put(`${API}/api/todos/${todo.id}`, { completed: !todo.completed });
    fetchTodos();
  };

  const deleteTodo = async (id) => {
    if (!window.confirm("Delete this task?")) return;
    await axios.delete(`${API}/api/todos/${id}`);
    fetchTodos();
  };

  const filtered = todos.filter(t =>
    filter === "all" ? true : filter === "active" ? !t.completed : t.completed
  );

  const counts = {
    all: todos.length,
    active: todos.filter(t => !t.completed).length,
    done: todos.filter(t => t.completed).length,
  };

  return (
    <div style={styles.page}>
      {/* Background blobs */}
      <div style={styles.blob1} />
      <div style={styles.blob2} />

      <div style={styles.container}>
        {/* Header */}
        <header style={styles.header}>
          <div>
            <h1 style={styles.logo}>Taskflow</h1>
            <p style={styles.tagline}>Your tasks. Your flow.</p>
          </div>
          <button style={styles.addBtn} onClick={openCreate}>
            <span style={{ fontSize: 20, lineHeight: 1 }}>+</span> New Task
          </button>
        </header>

        {/* Stats */}
        <div style={styles.statsRow}>
          {[
            { key: "all",    label: "Total",     val: counts.all },
            { key: "active", label: "Pending",   val: counts.active },
            { key: "done",   label: "Completed", val: counts.done },
          ].map(s => (
            <button
              key={s.key}
              style={{ ...styles.statCard, ...(filter === s.key ? styles.statActive : {}) }}
              onClick={() => setFilter(s.key)}
            >
              <span style={styles.statNum}>{s.val}</span>
              <span style={styles.statLabel}>{s.label}</span>
            </button>
          ))}
        </div>

        {/* Error */}
        {error && <div style={styles.errorBox}>{error}</div>}

        {/* Loading */}
        {loading && <div style={styles.loading}>Loading tasks…</div>}

        {/* Empty state */}
        {!loading && !error && filtered.length === 0 && (
          <div style={styles.empty}>
            <div style={styles.emptyIcon}>📋</div>
            <p style={styles.emptyText}>No tasks here yet.</p>
            <button style={styles.addBtn} onClick={openCreate}>Add your first task</button>
          </div>
        )}

        {/* Todo list */}
        <div style={styles.list}>
          {filtered.map(todo => (
            <div key={todo.id} style={{ ...styles.card, opacity: todo.completed ? 0.65 : 1 }}>
              <button style={styles.checkBtn} onClick={() => toggleComplete(todo)}>
                <div style={{
                  ...styles.checkbox,
                  background: todo.completed ? "#6c63ff" : "transparent",
                  borderColor: todo.completed ? "#6c63ff" : "#ccc",
                }}>
                  {todo.completed && <span style={{ color: "#fff", fontSize: 12 }}>✓</span>}
                </div>
              </button>

              <div style={styles.cardBody}>
                <div style={styles.cardTop}>
                  <span style={{
                    ...styles.priorityBadge,
                    color: PRIORITY_CONFIG[todo.priority]?.color || "#888",
                    background: PRIORITY_CONFIG[todo.priority]?.bg || "#f5f5f5",
                  }}>
                    {PRIORITY_CONFIG[todo.priority]?.label}
                  </span>
                  <span style={styles.dateText}>
                    {new Date(todo.created_at).toLocaleDateString()}
                  </span>
                </div>
                <p style={{
                  ...styles.cardTitle,
                  textDecoration: todo.completed ? "line-through" : "none",
                  color: todo.completed ? "#aaa" : "#1a1a2e",
                }}>
                  {todo.title}
                </p>
                {todo.description && (
                  <p style={styles.cardDesc}>{todo.description}</p>
                )}
              </div>

              <div style={styles.cardActions}>
                <button style={styles.iconBtn} onClick={() => openEdit(todo)} title="Edit">✏️</button>
                <button style={styles.iconBtn} onClick={() => deleteTodo(todo.id)} title="Delete">🗑️</button>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Modal */}
      {showForm && (
        <div style={styles.overlay} onClick={() => setShowForm(false)}>
          <div style={styles.modal} onClick={e => e.stopPropagation()}>
            <div style={styles.modalHeader}>
              <h2 style={styles.modalTitle}>{editTodo ? "Edit Task" : "New Task"}</h2>
              <button style={styles.closeBtn} onClick={() => setShowForm(false)}>✕</button>
            </div>

            <form onSubmit={handleSubmit}>
              <div style={styles.field}>
                <label style={styles.label}>Title *</label>
                <input
                  style={styles.input}
                  value={form.title}
                  onChange={e => setForm({ ...form, title: e.target.value })}
                  placeholder="What needs to be done?"
                  required
                  autoFocus
                />
              </div>

              <div style={styles.field}>
                <label style={styles.label}>Description</label>
                <textarea
                  style={{ ...styles.input, height: 80, resize: "vertical" }}
                  value={form.description}
                  onChange={e => setForm({ ...form, description: e.target.value })}
                  placeholder="Add details (optional)"
                />
              </div>

              <div style={styles.field}>
                <label style={styles.label}>Priority</label>
                <div style={styles.priorityRow}>
                  {Object.entries(PRIORITY_CONFIG).map(([key, cfg]) => (
                    <button
                      type="button"
                      key={key}
                      style={{
                        ...styles.priorityBtn,
                        background: form.priority === key ? cfg.bg : "#f8f8f8",
                        borderColor: form.priority === key ? cfg.color : "#e0e0e0",
                        color: form.priority === key ? cfg.color : "#666",
                        fontWeight: form.priority === key ? 600 : 400,
                      }}
                      onClick={() => setForm({ ...form, priority: key })}
                    >
                      {cfg.label}
                    </button>
                  ))}
                </div>
              </div>

              <div style={styles.formActions}>
                <button type="button" style={styles.cancelBtn} onClick={() => setShowForm(false)}>
                  Cancel
                </button>
                <button type="submit" style={styles.submitBtn}>
                  {editTodo ? "Save Changes" : "Add Task"}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}

const styles = {
  page: {
    minHeight: "100vh",
    background: "linear-gradient(135deg, #f5f3ff 0%, #ede9fe 50%, #f0fdf4 100%)",
    fontFamily: "'DM Sans', sans-serif",
    position: "relative",
    overflow: "hidden",
  },
  blob1: {
    position: "fixed", top: -120, right: -120,
    width: 400, height: 400, borderRadius: "50%",
    background: "radial-gradient(circle, rgba(108,99,255,0.15) 0%, transparent 70%)",
    pointerEvents: "none",
  },
  blob2: {
    position: "fixed", bottom: -100, left: -100,
    width: 350, height: 350, borderRadius: "50%",
    background: "radial-gradient(circle, rgba(16,185,129,0.12) 0%, transparent 70%)",
    pointerEvents: "none",
  },
  container: {
    maxWidth: 720, margin: "0 auto", padding: "40px 20px",
    position: "relative", zIndex: 1,
  },
  header: {
    display: "flex", justifyContent: "space-between", alignItems: "flex-start",
    marginBottom: 36,
  },
  logo: {
    fontFamily: "'Syne', sans-serif", fontWeight: 800,
    fontSize: 42, margin: 0, color: "#1a1a2e",
    letterSpacing: "-1px",
  },
  tagline: { margin: "4px 0 0", color: "#888", fontSize: 15 },
  addBtn: {
    display: "flex", alignItems: "center", gap: 8,
    background: "#6c63ff", color: "#fff", border: "none",
    padding: "12px 22px", borderRadius: 50, fontSize: 15,
    fontWeight: 600, cursor: "pointer", fontFamily: "'DM Sans', sans-serif",
    boxShadow: "0 4px 20px rgba(108,99,255,0.35)",
    transition: "transform 0.15s, box-shadow 0.15s",
  },
  statsRow: {
    display: "grid", gridTemplateColumns: "repeat(3,1fr)", gap: 16, marginBottom: 28,
  },
  statCard: {
    background: "#fff", border: "2px solid transparent", borderRadius: 16,
    padding: "18px 12px", textAlign: "center", cursor: "pointer",
    transition: "all 0.2s", fontFamily: "'DM Sans', sans-serif",
    boxShadow: "0 2px 12px rgba(0,0,0,0.06)",
    display: "flex", flexDirection: "column", alignItems: "center", gap: 4,
  },
  statActive: { borderColor: "#6c63ff", boxShadow: "0 4px 20px rgba(108,99,255,0.2)" },
  statNum: { fontSize: 28, fontWeight: 700, color: "#1a1a2e", fontFamily: "'Syne', sans-serif" },
  statLabel: { fontSize: 13, color: "#888" },
  errorBox: {
    background: "#fdecea", color: "#c0392b", padding: "14px 18px",
    borderRadius: 12, marginBottom: 20, fontSize: 14,
    border: "1px solid #f5c6cb",
  },
  loading: { textAlign: "center", color: "#888", padding: 40, fontSize: 16 },
  empty: {
    textAlign: "center", padding: "60px 20px",
    display: "flex", flexDirection: "column", alignItems: "center", gap: 16,
  },
  emptyIcon: { fontSize: 48 },
  emptyText: { color: "#aaa", fontSize: 16, margin: 0 },
  list: { display: "flex", flexDirection: "column", gap: 12 },
  card: {
    background: "#fff", borderRadius: 16, padding: "18px 20px",
    display: "flex", alignItems: "flex-start", gap: 16,
    boxShadow: "0 2px 12px rgba(0,0,0,0.06)",
    transition: "transform 0.15s, box-shadow 0.15s",
    border: "1px solid rgba(0,0,0,0.04)",
  },
  checkBtn: { background: "none", border: "none", cursor: "pointer", padding: 0, marginTop: 2 },
  checkbox: {
    width: 22, height: 22, borderRadius: 6, border: "2px solid",
    display: "flex", alignItems: "center", justifyContent: "center",
    transition: "all 0.2s",
  },
  cardBody: { flex: 1, minWidth: 0 },
  cardTop: { display: "flex", alignItems: "center", gap: 10, marginBottom: 6 },
  priorityBadge: {
    fontSize: 11, fontWeight: 600, padding: "3px 10px",
    borderRadius: 20, letterSpacing: "0.5px", textTransform: "uppercase",
  },
  dateText: { fontSize: 12, color: "#bbb", marginLeft: "auto" },
  cardTitle: { margin: "0 0 4px", fontSize: 16, fontWeight: 500, lineHeight: 1.4 },
  cardDesc: { margin: 0, fontSize: 13, color: "#888", lineHeight: 1.5 },
  cardActions: { display: "flex", gap: 4, flexShrink: 0 },
  iconBtn: {
    background: "none", border: "none", cursor: "pointer",
    fontSize: 16, padding: "4px 6px", borderRadius: 8,
    transition: "background 0.15s",
  },
  overlay: {
    position: "fixed", inset: 0, background: "rgba(0,0,0,0.4)",
    display: "flex", alignItems: "center", justifyContent: "center",
    zIndex: 100, padding: 20, backdropFilter: "blur(4px)",
  },
  modal: {
    background: "#fff", borderRadius: 20, padding: "28px 32px",
    width: "100%", maxWidth: 480,
    boxShadow: "0 20px 60px rgba(0,0,0,0.2)",
  },
  modalHeader: { display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 24 },
  modalTitle: {
    fontFamily: "'Syne', sans-serif", fontWeight: 700,
    fontSize: 22, margin: 0, color: "#1a1a2e",
  },
  closeBtn: {
    background: "#f5f5f5", border: "none", width: 32, height: 32,
    borderRadius: 8, cursor: "pointer", fontSize: 14, color: "#666",
  },
  field: { marginBottom: 20 },
  label: { display: "block", fontSize: 13, fontWeight: 500, color: "#555", marginBottom: 8 },
  input: {
    width: "100%", padding: "12px 14px", borderRadius: 10,
    border: "1.5px solid #e8e8e8", fontSize: 15, fontFamily: "'DM Sans', sans-serif",
    outline: "none", boxSizing: "border-box", transition: "border-color 0.2s",
    color: "#1a1a2e",
  },
  priorityRow: { display: "flex", gap: 10 },
  priorityBtn: {
    flex: 1, padding: "10px", borderRadius: 10, border: "1.5px solid",
    cursor: "pointer", fontSize: 14, fontFamily: "'DM Sans', sans-serif",
    transition: "all 0.2s",
  },
  formActions: { display: "flex", gap: 12, marginTop: 28 },
  cancelBtn: {
    flex: 1, padding: "13px", borderRadius: 10, border: "1.5px solid #e0e0e0",
    background: "#fff", fontSize: 15, cursor: "pointer",
    fontFamily: "'DM Sans', sans-serif", color: "#555",
  },
  submitBtn: {
    flex: 2, padding: "13px", borderRadius: 10, border: "none",
    background: "#6c63ff", color: "#fff", fontSize: 15, fontWeight: 600,
    cursor: "pointer", fontFamily: "'DM Sans', sans-serif",
    boxShadow: "0 4px 15px rgba(108,99,255,0.35)",
  },
};