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
};

export default function TextReviews() {
  const [reviews, setReviews] = useState<Review[]>([]);

  useEffect(() => {
    async function loadReviews() {
      const { data, error } = await supabase
        .from("testimonials")
        .select("id,name,location,quote,rating")
        .eq("published", true)
        .is("media_type", null)
        .gte("rating", 1)
        .lte("rating", 5)
        .order("created_at", { ascending: false })
        .limit(12);

      if (!error && data) setReviews(data);
    }

    void loadReviews();
  }, []);

  return (
    <section style={{
      padding: "40px 20px",
      background: "#f5f7f4"
    }}>
      <div style={{
        maxWidth: "1200px",
        margin: "auto"
      }}>
        <div style={{
          textAlign: "center",
          marginBottom: "30px"
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
          gap: "20px"
        }}>
          {reviews.map(review => (
            <article key={review.id} style={{
              background: "#fff",
              padding: "24px",
              borderRadius: "16px",
              boxShadow: "0 5px 20px #00000008",
              overflowWrap: "anywhere"
            }}>
              <div
                aria-label={`${review.rating} out of 5 stars`}
                style={{
                  color: "#eab308",
                  fontSize: "22px"
                }}
              >
                {"★".repeat(review.rating)}
                {"☆".repeat(5 - review.rating)}
              </div>

              <p style={{
                lineHeight: 1.7,
                color: "#444"
              }}>
                “{review.quote}”
              </p>

              <strong style={{ color: "#174b38" }}>
                {review.name}
              </strong>

              <div style={{
                color: "#777",
                fontSize: "14px"
              }}>
                {review.location}
              </div>
            </article>
          ))}
        </div>

        <div style={{
          textAlign: "center",
          marginTop: "25px"
        }}>
          <Link to="/review" className="button teal">
            Share Your Experience
          </Link>
        </div>
      </div>
    </section>
  );
}