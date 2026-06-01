import { RecommendationCardPlaceholder } from "./placeholder.js"; export { RecommendationCardPlaceholder };

import { html, nothing } from "../../utility/lit-core.min.js";
import { CustomElement, Golbal } from "../../utility/utility.js";

export class RecommendationCard extends CustomElement {

  static properties = {
    tmdb_id: { attribute: "card-tmdbid" },
    source_id: { attribute: "card-sourceid" },
    res_type: { attribute: "card-restype" },
    media_type: { attribute: "card-mediatype" },
    show_sub: { attribute: "card-showsub"},
    title: { attribute: "card-title" },
    fav: { attribute: "card-fav" , reflect: true},
    date: { attribute: "card-date" },
    vote: { attribute: "card-vote" },
    image: { attribute: "card-image" },
    overview: { attribute: "card-overview" },
    year: { attribute: "card-year" },
    site: { attribute: "card-site" },
    weekday: { attribute: "card-weekday" },
    compact: { attribute: "card-compact" },
    lazy: {},
  };

  _detail_id() {
    return this.tmdb_id || this.source_id || "";
  }

  _display_media_type() {
    if (this.res_type) {
      return this.res_type;
    }
    if (this.media_type === "MOV") {
      return "电影";
    }
    if (this.media_type === "TV") {
      return "电视剧";
    }
    return "";
  }

  _metadata() {
    return [this.year, this.date].filter((item) => item).join(" · ");
  }

  _render_vote() {
    if (!this.vote || this.vote == "0.0" || this.vote == "0") {
      return nothing;
    }
    return html`<span class="recommendation-card-vote">${this.vote}</span>`;
  }

  _render_fav_state() {
    if (this.fav == "2") {
      return html`<span class="recommendation-card-state recommendation-card-state-collected">已入库</span>`;
    }
    if (this.fav == "1") {
      return html`<span class="recommendation-card-state recommendation-card-state-subscribed">已订阅</span>`;
    }
    return nothing;
  }

  _open_detail() {
    const detail_id = this._detail_id();
    if (detail_id) {
      navmenu(`media_detail?type=${this.media_type}&id=${detail_id}`);
    }
  }

  _fav_change() {
    const options = {
      detail: {
        fav: this.fav
      },
      bubbles: true,
      composed: true,
    };
    this.dispatchEvent(new CustomEvent("fav_change", options));
  }

  _loveClick(e) {
    e.stopPropagation();
    Golbal.lit_love_click(this.title, this.year, this.media_type, this._detail_id(), this.fav,
      () => {
        this.fav = "0";
        this._fav_change();
      },
      () => {
        this.fav = "1";
        this._fav_change();
      });
  }

  _searchClick(e) {
    e.stopPropagation();
    media_search(this._detail_id(), this.title, this.media_type);
  }

  render() {
    const metadata = this._metadata();
    return html`
      <div class="lit-recommendation-card ${this.compact == "1" ? "recommendation-card-compact" : ""} cursor-pointer" @click=${this._open_detail}>
        ${this._render_fav_state()}
        <div class="recommendation-card-poster">
          <img class="recommendation-card-image"
               alt=""
               src=${this.lazy == "1" ? "" : this.image || Golbal.noImage}
               @error=${() => { if (this.lazy != "1") { this.image = Golbal.noImage; } }}/>
          ${this.weekday
            ? html`<span class="badge bg-orange recommendation-card-poster-badge">${this.weekday}</span>`
            : nothing}
        </div>
        <div class="recommendation-card-body">
          <div class="recommendation-card-topline">
            ${this._display_media_type()
              ? html`<span class="recommendation-card-kind">${this._display_media_type()}</span>`
              : nothing}
            ${this._render_vote()}
          </div>
          <h3 class="recommendation-card-title">${this.title}</h3>
          ${metadata ? html`<div class="recommendation-card-meta">${metadata}</div>` : nothing}
          ${this.overview
            ? html`<p class="recommendation-card-overview">${this.overview}</p>`
            : html`<p class="recommendation-card-overview text-muted">暂无简介</p>`}
          ${this.show_sub == "1"
            ? html`
              <div class="recommendation-card-actions">
                <button class="recommendation-card-action"
                        type="button"
                        title="搜索资源"
                        @click=${this._searchClick}>
                  <svg xmlns="http://www.w3.org/2000/svg" class="icon" width="20" height="20"
                       viewBox="0 0 24 24" stroke-width="2" stroke="currentColor" fill="none"
                       stroke-linecap="round" stroke-linejoin="round">
                    <path stroke="none" d="M0 0h24v24H0z" fill="none"></path>
                    <circle cx="10" cy="10" r="7"></circle>
                    <line x1="21" y1="21" x2="15" y2="15"></line>
                  </svg>
                  <span>搜索</span>
                </button>
                <button class="recommendation-card-action"
                        type="button"
                        title="加入/取消订阅"
                        @click=${this._loveClick}>
                  <svg xmlns="http://www.w3.org/2000/svg" class="icon ${this.fav == "1" ? "icon-filled text-red" : ""}" width="20" height="20"
                       viewBox="0 0 24 24" stroke-width="2" stroke="currentColor" fill="none"
                       stroke-linecap="round" stroke-linejoin="round">
                    <path stroke="none" d="M0 0h24v24H0z" fill="none"></path>
                    <path d="M19.5 12.572l-7.5 7.428l-7.5 -7.428m0 0a5 5 0 1 1 7.5 -6.566a5 5 0 1 1 7.5 6.572"></path>
                  </svg>
                  <span>订阅</span>
                </button>
              </div>`
            : nothing}
        </div>
      </div>
    `;
  }
}

window.customElements.define("recommendation-card", RecommendationCard);
