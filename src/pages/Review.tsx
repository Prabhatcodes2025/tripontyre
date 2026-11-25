import { useState } from "react";
import type { FormEvent } from "react";
import { createClient } from "@supabase/supabase-js";

const supabase = createClient(
  import.meta.env.VITE_SUPABASE_URL,
  import.meta.env.VITE_SUPABASE_ANON_KEY
);

export default function Review() {
  const [name, setName] = useState("");
  const [location, setLocation] = useState("");
  const [quote, setQuote] = useState("");
  const [rating, setRating] = useState(5);
  const [loading, setLoading] = useState(false);
  const [success, setSuccess] = useState(false);
  const [error, setError] = useState("");

  async function submitReview(e: FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError("");

    try {
      const { error } = await supabase
        .from("testimonials")
        .insert({
          name: name.trim(),
          location: location.trim(),
          quote: quote.trim(),
          rating,
          published: false,
          media_url: null,
          media_type: null,
          poster_url: null
        });

      if (error) throw error;
      setSuccess(true);
    } catch {
      setError("Unable to submit review. Please try again.");
    } finally {
      setLoading(false);
    }
  }

  const fieldStyle = {
    width: "100%",
    padding: "14px",
    border: "1px solid #ddd",
    borderRadius: "10px",
    marginBottom: "18px",
    boxSizing: "border-box" as const,
    fontSize: "16px"
  };

  return (
    <section style={{
      background: "#f4f7f5",
      padding: "40px 16px",
      minHeight: "80vh"
    }}>
      <div style={{
        maxWidth: "550px",
        margin: "auto",
        padding: "28px",
        background: "#fff",
        borderRadius: "20px",
        boxShadow: "0 10px 40px #00000010"
      }}>
        {success ? (
          <div style={{ textAlign: "center", padding: "30px 0" }}>
            <h1>Thank You!</h1>
            <p>Your review has been submitted successfully.</p>
            <p>We appreciate your valuable feedback.</p>
            <a href="/">Back to Homepage</a>
          </div>
        ) : (
          <>
            <h1 style={{ textAlign: "center", color: "#174b38" }}>
              Share Your Travel Experience
            </h1>

            <p style={{ textAlign: "center", color: "#666" }}>
              Tell us about your journey with My Tripon Travel.
            </p>

            <form onSubmit={submitReview}>
              <div style={{
                textAlign: "center",
                margin: "25px 0"
              }}>
                {[1, 2, 3, 4, 5].map((star) => (
                  <button
                    key={star}
                    type="button"
                    aria-label={`${star} stars`}
                    aria-pressed={rating === star}
                    onClick={() => setRating(star)}
                    style={{
                      border: "none",
                      background: "transparent",
                      color: star <= rating ? "#eab308" : "#ddd",
                      fontSize: "38px",
                      cursor: "pointer"
                    }}
                  >
                    ★
                  </button>
                ))}
              </div>

              <input
                style={fieldStyle}
                placeholder="Your Full Name"
                aria-label="Full Name"
                value={name}
                onChange={(e) => setName(e.target.value)}
                minLength={2}
                maxLength={100}
                required
              />

              <input
                style={fieldStyle}
                placeholder="Tour / Destination"
                aria-label="Tour or Destination"
                value={location}
                onChange={(e) => setLocation(e.target.value)}
                maxLength={150}
                required
              />

              <textarea
                style={fieldStyle}
                placeholder="Tell us about your travel experience..."
                aria-label="Your review"
                value={quote}
                onChange={(e) => setQuote(e.target.value)}
                rows={5}
                minLength={10}
                maxLength={2000}
                required
              />

              {error && <p role="alert" style={{ color: "red" }}>{error}</p>}

              <button
                type="submit"
                disabled={loading}
                style={{
                  width: "100%",
                  padding: "15px",
                  background: "#174b38",
                  color: "#fff",
                  border: "none",
                  borderRadius: "10px",
                  fontSize: "16px",
                  cursor: "pointer"
                }}
              >
                {loading ? "Submitting..." : "Submit Review"}
              </button>
            </form>
          </>
        )}
      </div>
    </section>
  );
}