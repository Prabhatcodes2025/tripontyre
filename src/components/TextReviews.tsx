import { useEffect, useState } from "react";
import { createClient } from "@supabase/supabase-js";
import { Link } from "react-router-dom";

const supabase = createClient(
  import.meta.env.VITE_SUPABASE_URL,
  import.meta.env.VITE_SUPABASE_ANON_KEY
);

type Review = {
  id: string;
  name: string;
  location: string;
  quote: string;
  rating: number;
  media_type: string | null;
  media_url: string | null;
  signedUrl?: string;
};

export default function TextReviews() {
  const [reviews, setReviews] = useState<Review[]>([]);

  useEffect(() => {
    let active = true;

    async function loadReviews() {
      const { data, error } = await supabase
        .from("testimonials")
        .select("id,name,location,quote,rating,media_type,media_url")
        .eq("published", true)
        .or("media_type.is.null,media_type.eq.text,media_url.like.customers/%")
        .gte("rating", 1)
        .lte("rating", 5)
        .order("created_at", { ascending: false })
        .limit(12);

      if (error || !data) return;

      const results = await Promise.all(
        data.map(async (review): Promise<Review> => {
          if (
            review.media_url?.startsWith("customers/") &&
            ["image", "video"].includes(review.media_type || "")
          ) {
            const { data: signed } = await supabase.storage
              .from("review-uploads")
              .createSignedUrl(review.media_url, 3600);

            return {
              ...review,
              signedUrl: signed?.signedUrl
            };
          }

          return review;
        })
      );

      if (active) setReviews(results);
    }

    void loadReviews();

    const timer = window.setInterval(loadReviews, 3000000);

    return () => {
      active = false;
      window.clearInterval(timer);
    };
  }, []);

  return (
    <section style={{
      padding: "50px 20px",
      background: "#f5f7f4"
    }}>
      <div style={{
        maxWidth: "1200px",
        margin: "auto"
      }}>
        <div style={{
          textAlign: "center",
          marginBottom: "35px"
        }}>
          <span className="section-overline">
            TRAVELLER EXPERIENCES
          </span>

          <h2 style={{ color: "#174b38" }}>
            What Our Travellers Say
          </h2>

          <p>Real journeys. Real experiences.</p>
        </div>

        <div style={{
          display: "grid",
          gridTemplateColumns:
            "repeat(auto-fit, minmax(min(100%, 280px), 1fr))",
          gap: "24px"
        }}>
          {reviews.map(review => (
            <article key={review.id} style={{
              background: "#fff",
              padding: "20px",
              borderRadius: "18px",
              boxShadow: "0 5px 25px #0000000c",
              overflowWrap: "anywhere",
              overflow: "hidden"
            }}>

              {review.signedUrl &&
                review.media_type === "image" && (
                <a
                  href={review.signedUrl}
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  <img
                    src={review.signedUrl}
                    alt={`Travel experience shared by ${review.name}`}
                    loading="lazy"
                    style={{
                      width: "100%",
                      height: "230px",
                      objectFit: "cover",
                      borderRadius: "12px",
                      marginBottom: "16px"
                    }}
                  />
                </a>
              )}

              {review.signedUrl &&
                review.media_type === "video" && (
                <video
                  src={review.signedUrl}
                  controls
                  playsInline
                  preload="metadata"
                  style={{
                    width: "100%",
                    height: "230px",
                    objectFit: "contain",
                    background: "#000",
                    borderRadius: "12px",
                    marginBottom: "16px"
                  }}
                />
              )}

              <div
                aria-label={`${review.rating} out of 5 stars`}
                style={{
                  color: "#eab308",
                  fontSize: "23px",
                  marginBottom: "12px"
                }}
              >
                {"★".repeat(review.rating)}
                {"☆".repeat(5 - review.rating)}
              </div>

              <p style={{
                lineHeight: 1.7,
                color: "#444",
                marginBottom: "18px"
              }}>
                “{review.quote}”
              </p>

              <div style={{
                display: "flex",
                alignItems: "center",
                gap: "12px"
              }}>
                <div style={{
                  width: "44px",
                  height: "44px",
                  borderRadius: "50%",
                  background: "#e5efe8",
                  color: "#174b38",
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                  fontWeight: 700,
                  flexShrink: 0
                }}>
                  {review.name.charAt(0).toUpperCase()}
                </div>

                <div>
                  <strong style={{ color: "#174b38" }}>
                    {review.name}
                  </strong>

                  <div style={{
                    color: "#777",
                    fontSize: "14px"
                  }}>
                    {review.location}
                  </div>
                </div>
              </div>

            </article>
          ))}
        </div>

        <div style={{
          textAlign: "center",
          marginTop: "30px"
        }}>
          <Link to="/review" className="button teal">
            Share Your Experience
          </Link>
        </div>
      </div>
    </section>
  );
}