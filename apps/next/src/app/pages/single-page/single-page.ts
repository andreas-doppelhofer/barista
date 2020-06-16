/**
 * @license
 * Copyright 2020 Dynatrace LLC
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import { AfterViewInit, Component, OnInit } from '@angular/core';
import {
  BaSinglePageContent,
} from '@dynatrace/shared/barista-definitions';
import {
  BaPageService,
} from 'libs/shared/data-access-strapi/src/lib/page.service';

@Component({
  selector: 'ba-single-page',
  templateUrl: 'single-page.html',
  styleUrls: ['single-page.scss'],
  host: {
    class: 'ba-page',
  },
})
export class BaSinglePage implements OnInit, AfterViewInit {
  /** @internal The current page content from the cms */
  _pageContent = this._pageService._getCurrentPage();

  constructor(
    private _pageService: BaPageService<BaSinglePageContent>,
  ) {}

  ngOnInit(): void {

  }

  ngAfterViewInit(): void {

  }
}
