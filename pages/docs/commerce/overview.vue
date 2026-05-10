<template>
  <div>
    <h1>Commerce overview</h1>
    <p>The Commerce module turns Pulse into an end-to-end e-commerce engagement platform. When enabled, the workspace gains:</p>
    <ul>
      <li>Product catalog (<code>commerce_products</code>) for recommendations and abandoned-cart flows.</li>
      )
      <li>Shopify and WooCommerce webhook ingestion to populate <code>commerce_orders</code>.</li>
      <li>Automatic last-touch revenue attribution back to campaigns.</li>
      <li>Commerce-specific event emissions (<code>order_created</code>, <code>order_completed</code>).</li>
    </ul>

    <h2>Enabling commerce</h2>
    <ol>
      <li>Go to <strong>Settings → Workspace → Feature modules</strong>.</li>
      <li>Toggle <em>Commerce</em> on. Only workspace owners can change this.</li>
    </ol>
    <p>Enabling commerce adds the <em>Products</em> sidebar link and a <em>Shopify / Woo</em> tab under Integrations. Disabling hides them again but never deletes existing data.</p>

    <h2>When to leave it off</h2>
    <p>Fintech, SaaS, media, gaming, and healthcare workspaces typically don't need a product catalog. Leaving commerce disabled keeps the UI focused and avoids confusing teammates with modules that don't apply to your business.</p>

    <h2>Data model</h2>
    <table>
      <thead><tr><th>Table</th><th>Purpose</th></tr></thead>
      <tbody>
        <tr><td><code>commerce_products</code></td><td>Product catalog. Used for recommendations and abandoned-cart.</td></tr>
        <tr><td><code>commerce_orders</code></td><td>Normalized order records from Shopify / Woo / manual upload.</td></tr>
        <tr><td><code>campaign_attributions</code></td><td>Links orders back to the last campaign that touched the buyer.</td></tr>
        <tr><td><code>campaign_revenue_v</code></td><td>Read-only view summing attributed revenue per campaign.</td></tr>
      </tbody>
    </table>

    <div class="card-row">
      <NuxtLink to="/docs/commerce/shopify" class="card-link">
        <div class="title">Connect Shopify</div>
        <div class="desc">Webhooks, ingestion, and order mapping.</div>
      </NuxtLink>
      <NuxtLink to="/docs/commerce/woocommerce" class="card-link">
        <div class="title">Connect WooCommerce</div>
        <div class="desc">Webhook setup and normalization.</div>
      </NuxtLink>
      <NuxtLink to="/docs/commerce/attribution" class="card-link">
        <div class="title">Revenue attribution</div>
        <div class="desc">How Pulse assigns revenue to campaigns.</div>
      </NuxtLink>
    </div>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'docs' })
useHead({ title: 'Commerce · Pulse Docs' })
</script>
