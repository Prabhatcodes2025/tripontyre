import { useState } from "react";
import type { FormEvent } from "react";
import { createClient } from "@supabase/supabase-js";
import { Turnstile } from "@marsidev/react-turnstile";

const supabase = createClient(
  import.meta.env.VITE_SUPABASE_URL,
  import.meta.env.VITE_SUPABASE_ANON_KEY
);

const SITE_KEY = "0x4AAAAAAGS_y_-QKvHScP9f";

const allowedTypes = [
  "image/jpeg",
  "image/png",
  "image/webp",
  "video/mp4",
  "video/webm"
];

export default function Review() {
  const [name, setName] = useState("");
  const [location, setLocation] = useState("");
  const [quote, setQuote] = useState("");
  const [rating, setRating] = useState(5);
  const [file, setFile] = useState<File | null>(null);
  const [path, setPath] = useState("");
  const [captchaToken, setCaptchaToken] = useState("");
  const [captchaKey, setCaptchaKey] = useState(0);
  const [loading, setLoading] = useState(false);
  const [success, setSuccess] = useState(false);
  const [error, setError] = useState("");
  const [status, setStatus] = useState("");

  function resetCaptcha() {
    setCaptchaToken("");
    setCaptchaKey((key) => key + 1);
  }

  function selectFile(selected: File | null) {
    setError("");
    setFile(null);
    setPath("");
    setStatus("");

    if (!selected) return;

    if (!allowedTypes.includes(selected.type)) {
      setError("Please select a JPG, PNG, WebP, MP4 or WebM file.");
      return;
    }

    const maxSize = selected.type.startsWith("video/")
      ? 50 * 1024 * 1024
      : 5 * 1024 * 1024;

    if (selected.size <= 0 || selected.size > maxSize) {
      setError("Photo limit: 5 MB. Video limit: 50 MB.");
      return;
    }

    setFile(selected);
  }

  async function submitReview(e: FormEvent) {
    e.preventDefault();

    if (!captchaToken) {
      setError("Please complete the security verification.");
      return;
    }

    setLoading(true);
    setError("");

    try {
      if (file && !path) {
        setStatus("Preparing your upload...");

        const { data, error: uploadError } =
          await supabase.functions.invoke("review-upload", {
            body: {
              mimeType: file.type,
              fileSize: file.size,
              captchaToken
            }
          });

        if (uploadError || !data?.token || !data?.path) {
          throw new Error("Unable to prepare media upload.");
        }

        setStatus("Uploading your media. Please wait...");

        const { error: storageError } = await supabase.storage
          .from("review-uploads")
          .uploadToSignedUrl(data.path, data.token, file, {
            contentType: file.type
          });

        if (storageError) {
          throw new Error("Media upload failed.");
        }

        setPath(data.path);
        setStatus(
          "Media uploaded successfully. Complete verification and submit your review."
        );

        return;
      }

      setStatus("Submitting your review...");

      const { data, error: submitError } =
        await supabase.functions.invoke("review-submit", {
          body: {
            name: name.trim(),
            location: location.trim(),
            quote: quote.trim(),
            rating,
            path,
            captchaToken
          }
        });

      if (submitError || !data?.success) {
        throw new Error("Unable to submit review. Please try again.");
      }

      setSuccess(true);
      setStatus("");

    } catch (err) {
      setError(
        err instanceof Error ? err.message : "Something went wrong."
      );
      setStatus("");
    } finally {
      setLoading(false);
      resetCaptcha();
    }
  }

  const fieldStyle = {
    width: "100%",
    padding: "14px",
    border: "1px solid #d1d5db",
    borderRadius: "10px",
    marginBottom: "18px",
    boxSizing: "border-box" as const,
    fontSize: "16px",
    background: "#fff",
    color: "#222"
  };

  return (
    <section style={{
      background: "#f4f7f5",
      padding: "40px 16px",
      minHeight: "80vh"
    }}>
      <div style={{
        maxWidth: "600px",
        margin: "auto",
        padding: "28px",
        background: "#fff",
        borderRadius: "20px",
        boxShadow: "0 10px 40px #00000010"
      }}>
        {success ? (
          <div style={{ textAlign: "center", padding: "30px 0" }}>
            <div style={{ fontSize: "50px" }}>✓</div>
            <h1 style={{ color: "#174b38" }}>Thank You!</h1>
            <p>Your review has been submitted successfully.</p>
            <p>It will appear on our website after approval.</p>
            <a href="/">Back to Homepage</a>
          </div>
        ) : (
          <>
            <h1 style={{
              textAlign: "center",
              color: "#174b38"
            }}>
              Share Your Travel Experience
            </h1>

            <p style={{
              textAlign: "center",
              color: "#666"
            }}>
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
                    disabled={loading}
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
                aria-label="Full name"
                value={name}
                onChange={(e) => setName(e.target.value)}
                minLength={2}
                maxLength={100}
                disabled={loading}
                required
              />

              <input
                style={fieldStyle}
                placeholder="Tour / Destination"
                aria-label="Tour or destination"
                value={location}
                onChange={(e) => setLocation(e.target.value)}
                maxLength={150}
                disabled={loading}
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
                disabled={loading}
                required
              />

              <div style={{
                padding: "20px",
                border: "2px dashed #b9cfc3",
                borderRadius: "14px",
                background: "#f7faf8",
                marginBottom: "20px"
              }}>
                <strong style={{ color: "#174b38" }}>
                  Upload Photo or Video (Optional)
                </strong>

                <p style={{
                  fontSize: "13px",
                  color: "#666"
                }}>
                  Photo: Max 5 MB | Video: Max 50 MB
                </p>

                <input
                  type="file"
                  aria-label="Upload photo or video"
                  accept="image/jpeg,image/png,image/webp,video/mp4,video/webm"
                  disabled={loading || !!path}
                  onChange={(e) => {
                    selectFile(e.target.files?.[0] || null);
                    e.target.value = "";
                  }}
                  style={{ maxWidth: "100%" }}
                />

                {file && (
                  <p style={{
                    color: "#174b38",
                    overflowWrap: "anywhere"
                  }}>
                    Selected: {file.name}
                  </p>
                )}

                {path && (
                  <p style={{ color: "green" }}>
                    ✓ Media uploaded successfully
                  </p>
                )}

                {file && !path && !loading && (
                  <button
                    type="button"
                    onClick={() => selectFile(null)}
                  >
                    Remove file
                  </button>
                )}
              </div>

              <div style={{
                marginBottom: "20px",
                display: "flex",
                justifyContent: "center"
              }}>
                <Turnstile
                  key={captchaKey}
                  siteKey={SITE_KEY}
                  onSuccess={setCaptchaToken}
                  onExpire={() => setCaptchaToken("")}
                  onError={() => setCaptchaToken("")}
                  options={{
                    theme: "light",
                    size: "flexible"
                  }}
                />
              </div>

              {status && (
                <p role="status" style={{ color: "#174b38" }}>
                  {status}
                </p>
              )}

              {error && (
                <p role="alert" style={{ color: "#dc2626" }}>
                  {error}
                </p>
              )}

              <button
                type="submit"
                disabled={loading || !captchaToken}
                style={{
                  width: "100%",
                  padding: "15px",
                  background: "#174b38",
                  color: "#fff",
                  border: "none",
                  borderRadius: "10px",
                  fontSize: "16px",
                  fontWeight: 600,
                  opacity: loading || !captchaToken ? 0.6 : 1,
                  cursor: loading ? "wait" : "pointer"
                }}
              >
                {loading
                  ? "Please wait..."
                  : file && !path
                    ? "Upload Media"
                    : "Submit Review"}
              </button>
            </form>
          </>
        )}
      </div>
    </section>
  );
}