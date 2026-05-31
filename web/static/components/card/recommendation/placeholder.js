import { html } from "../../utility/lit-core.min.js";
import { CustomElement } from "../../utility/utility.js";

export class RecommendationCardPlaceholder extends CustomElement {
  render() {
    return html`
      <div class="lit-recommendation-card placeholder-glow">
        <div class="recommendation-card-poster">
          <div class="placeholder w-100 h-100"></div>
        </div>
        <div class="recommendation-card-body">
          <div class="placeholder col-4 mb-3"></div>
          <div class="placeholder col-9 mb-2"></div>
          <div class="placeholder col-6 mb-4"></div>
          <div class="placeholder col-12 mb-2"></div>
          <div class="placeholder col-11 mb-2"></div>
          <div class="placeholder col-8"></div>
        </div>
      </div>
    `;
  }
}

window.customElements.define("recommendation-card-placeholder", RecommendationCardPlaceholder);
