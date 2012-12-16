// Copyright 2010 The Apache Software Foundation
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
package org.example.testapp.entities;

import javax.validation.constraints.*;
import java.util.ArrayList;
import java.util.Collection;

public class TestEntity
{
    @NotNull
    private String notNullValue;

    @Null
    private String nullValue;

    @Max(100)
    private int maxValue;

    @Min(6)
    private int minValue;

    @Size(min = 3, max = 6)
    private String stringSizeValue;

    @Size(min = 2, max = 3)
    private Collection<String> collectionSizeValue = new ArrayList<String>();

    public String getNotNullValue()
    {
        return notNullValue;
    }

    public void setNotNullValue(String notNullValue)
    {
        this.notNullValue = notNullValue;
    }

    public String getNullValue()
    {
        return nullValue;
    }

    public void setNullValue(String nullValue)
    {
        this.nullValue = nullValue;
    }

    public int getMaxValue()
    {
        return maxValue;
    }

    public void setMaxValue(int maxValue)
    {
        this.maxValue = maxValue;
    }

    public int getMinValue()
    {
        return minValue;
    }

    public void setMinValue(int minValue)
    {
        this.minValue = minValue;
    }


    public String getStringSizeValue()
    {
        return stringSizeValue;
    }

    public void setStringSizeValue(String stringSizeValue)
    {
        this.stringSizeValue = stringSizeValue;
    }

    public Collection<String> getCollectionSizeValue()
    {
        return collectionSizeValue;
    }

    public void setCollectionSizeValue(Collection<String> collectionSizeValue)
    {
        this.collectionSizeValue = collectionSizeValue;
    }
}
